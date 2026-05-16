provider "aws" {
  region = var.region
}

# 1. Target Group for Prometheus
resource "aws_lb_target_group" "prometheus" {
  name        = "${var.project_name}-prom-tg"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path     = "/-/healthy"
    interval = 30
  }
}

# 2. Routing Rule for the shared ALB
resource "aws_lb_listener_rule" "prometheus" {
  listener_arn = var.https_listener_arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }
  condition {
    host_header {
      values = ["prometheus.${var.domain_name}"]
    }
  }
}

# 3. DNS Record for Prometheus
data "aws_route53_zone" "main" {
  name = var.domain_name
}

data "aws_lb" "selected" {
  name = "${var.project_name}-alb"
}

resource "aws_route53_record" "prometheus" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "prometheus.${var.domain_name}"
  type    = "A"
  alias {
    name                   = data.aws_lb.selected.dns_name
    zone_id                = data.aws_lb.selected.zone_id
    evaluate_target_health = true
  }
}

# 4. ECS Task Definition
resource "aws_ecs_task_definition" "prometheus" {
  family                   = "${var.project_name}-prometheus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([{
    name  = "prometheus"
    image = "prom/prometheus:latest"
    portMappings = [{ containerPort = 9090 }]
    mountPoints = [{
      sourceVolume  = "prometheus-storage"
      containerPath = "/prometheus"
      readOnly      = false
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project_name}/prometheus"
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "prometheus"
      }
    }
  }])

  volume {
    name = "prometheus-storage"
    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.efs_prometheus_access_point_id
        iam             = "ENABLED"
      }
    }
  }
}

resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/${var.project_name}/prometheus"
  retention_in_days = 7
}

# 5. ECS Service
resource "aws_ecs_service" "prometheus" {
  name            = "${var.project_name}-prometheus"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [var.ecs_tasks_security_group_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus.arn
    container_name   = "prometheus"
    container_port   = 9090
  }

  depends_on = [aws_lb_listener_rule.prometheus]
}