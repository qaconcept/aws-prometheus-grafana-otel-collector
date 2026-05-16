provider "aws" {
  region = var.region
}

# 1. Target Group for Grafana
resource "aws_lb_target_group" "grafana" {
  name        = "${var.project_name}-graf-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path     = "/api/health"
    interval = 30
  }
}

# 2. Add Routing Rule to the existing shared HTTPS Listener
resource "aws_lb_listener_rule" "grafana" {
  listener_arn = var.https_listener_arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
  condition {
    host_header {
      values = ["grafana.${var.domain_name}"]
    }
  }
}

# 3. DNS Record for Grafana
data "aws_route53_zone" "main" {
  name = var.domain_name
}

data "aws_lb" "selected" {
  name = "${var.project_name}-alb"
}

resource "aws_route53_record" "grafana" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "grafana.${var.domain_name}"
  type    = "A"
  alias {
    name                   = data.aws_lb.selected.dns_name
    zone_id                = data.aws_lb.selected.zone_id
    evaluate_target_health = true
  }
}

# 4. Grafana ECS Task Definition (with EFS Persistence)
resource "aws_ecs_task_definition" "grafana" {
  family                   = "${var.project_name}-grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([{
    name  = "grafana"
    image = "grafana/grafana:latest"
    portMappings = [{ containerPort = 3000 }]
    
    healthCheck = {
      command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 15
    }

    environment = [
      { name = "GF_SECURITY_ADMIN_PASSWORD", value = "admin123" } # Sets initial admin password
    ]
    mountPoints = [{
      sourceVolume  = "grafana-storage"
      containerPath = "/var/lib/grafana"
      readOnly      = false
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project_name}/grafana"
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "grafana"
      }
    }
  }])

  volume {
    name = "grafana-storage"
    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.efs_grafana_access_point_id
        iam             = "ENABLED"
      }
    }
  }
}

resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/${var.project_name}/grafana"
  retention_in_days = 7
}

# 5. ECS Service
resource "aws_ecs_service" "grafana" {
  name            = "${var.project_name}-grafana"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [var.ecs_tasks_security_group_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener_rule.grafana]
}