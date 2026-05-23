provider "aws" { region = var.region }

locals { name = var.project_name }

# 1. ECS Cluster
resource "aws_ecs_cluster" "monitoring" {
  name = "${local.name}-cluster"
}

data "aws_route53_zone" "main" { name = var.domain_name }

# --- CONDITIONAL CERTIFICATE LOGIC ---

# IF create_ssl_cert is FALSE: Fetch the existing certificate
data "aws_acm_certificate" "existing_cert" {
  count       = var.create_ssl_cert ? 0 : 1
  domain      = var.domain_name 
  statuses    = ["ISSUED"]
  most_recent = true
}

# IF create_ssl_cert is TRUE: Create a new certificate
resource "aws_acm_certificate" "cert" {
  count             = var.create_ssl_cert ? 1 : 0
  domain_name       = "*.${var.domain_name}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.create_ssl_cert ? {
    for dvo in aws_acm_certificate.cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "main" {
  count                   = var.create_ssl_cert ? 1 : 0
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# --- END CONDITIONAL LOGIC ---

# 3. ALB & Jaeger Target Group
resource "aws_lb" "main" {
  name               = "${local.name}-alb"
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnets
}

resource "aws_lb_target_group" "jaeger" {
  name        = "${local.name}-jaeger-tg"
  port        = 16686
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check { path = "/" }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  
  # Selects the ARN dynamically based on the toggle
  certificate_arn   = var.create_ssl_cert ? aws_acm_certificate_validation.main[0].certificate_arn : data.aws_acm_certificate.existing_cert[0].arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jaeger.arn
  }
}

# 4. Route 53 Record for Jaeger
resource "aws_route53_record" "jaeger" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "jaeger.${var.domain_name}"
  type    = "A"
  
  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# 5. Jaeger ECS Service
resource "aws_ecs_task_definition" "jaeger" {
  family                   = "${local.name}-jaeger"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn
  
  container_definitions = jsonencode([{
    name  = "jaeger"
    image = "jaegertracing/all-in-one:latest"
    portMappings = [
      { containerPort = 16686 },
      { containerPort = 14269 }
    ]
    healthCheck = {
      command     = ["CMD-SHELL", "pgrep -f heartbeat.py || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${local.name}/jaeger"
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "jaeger"
      }
    }
  }])
}

resource "aws_cloudwatch_log_group" "jaeger" { name = "/ecs/${local.name}/jaeger" }

resource "aws_ecs_service" "jaeger" {
  name            = "${local.name}-jaeger"
  cluster         = aws_ecs_cluster.monitoring.id
  task_definition = aws_ecs_task_definition.jaeger.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  
  depends_on = [aws_lb_listener.https]

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [var.ecs_tasks_security_group_id]
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.jaeger.arn
    container_name   = "jaeger"
    container_port   = 16686
  }
}