provider "aws" {
  region = var.region
}

# 1. Store the OTel Collector Configuration in SSM Parameter Store
resource "aws_ssm_parameter" "otel_config" {
  name        = "/ecs/${var.project_name}/otel-collector-config"
  type        = "String"
  description = "OpenTelemetry Collector configuration pipeline"
  value       = jsonencode({
    receivers = {
      otlp = {
        protocols = {
          grpc = { endpoint = "0.0.0.0:4317" }
          http = { endpoint = "0.0.0.0:4318" }
        }
      }
    }
    processors = {
      batch = {}
    }
    exporters = {
      prometheus = {
        endpoint  = "0.0.0.0:8889"
        namespace = "otel"
      }
      "otlp/jaeger" = {
        endpoint = "sre-concepts-jaeger.local:4317"
        tls = {
          insecure = true
        }
      }
      debug = {                # Changed from 'logging' to 'debug'
        verbosity = "detailed"
      }
    }
    service = {
      pipelines = {
        metrics = {
          receivers  = ["otlp"]
          processors = ["batch"]
          exporters  = ["prometheus", "debug"] # Updated to reference debug
        }
        traces = {
          receivers  = ["otlp"]
          processors = ["batch"]
          exporters  = ["otlp/jaeger", "debug"] # Updated to reference debug
        }
      }
    }
  })
}

# 2. ECS CloudWatch Log Group
resource "aws_cloudwatch_log_group" "otel" {
  name              = "/ecs/${var.project_name}/otel-collector"
  retention_in_days = 7
}

# 3. Create the missing Service Discovery Private DNS Namespace
resource "aws_service_discovery_private_dns_namespace" "ecs_domain" {
  name        = "sreconcepts.local"
  description = "Private Service Connect namespace for ECS microservices"
  vpc         = var.vpc_id
}

# 4. ECS Task Definition
resource "aws_ecs_task_definition" "otel" {
  family                   = "${var.project_name}-otel-collector"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([{
    name  = "otel-collector"
    image = "otel/opentelemetry-collector-contrib:latest"
    
    portMappings = [
      { 
        name          = "otlp-grpc"
        containerPort = 4317
        hostPort      = 4317
        protocol      = "tcp"
      },
      { 
        name          = "otlp-http"
        containerPort = 4318
        hostPort      = 4318
        protocol      = "tcp"
      },
      { 
        name          = "prom-exporter"
        containerPort = 8889
        hostPort      = 8889
        protocol      = "tcp"
      }
    ]
    
    secrets = [{
      name      = "OTEL_COLLECTOR_CONFIG"
      valueFrom = aws_ssm_parameter.otel_config.arn
    }]

    command = ["--config=env:OTEL_COLLECTOR_CONFIG"]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project_name}/otel-collector"
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "otel"
      }
    }
  }])
}

# 5. ECS Service (Referencing the namespace cleanly)
resource "aws_ecs_service" "otel" {
  name            = "${var.project_name}-otel-collector"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.otel.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [var.ecs_tasks_security_group_id]
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.ecs_domain.arn # Uses the exact resource ARN
    service {
      port_name       = "otlp-grpc"
      discovery_name  = "otel-collector"
      client_alias {
        port = 4317
      }
    }
  }
}

# 6. Grant ECS Task Execution Role permissions to read the SSM Parameter
data "aws_iam_role" "execution_role" {
  name = "sre-concepts-execution-role"
}

resource "aws_iam_policy" "otel_ssm_policy" {
  name        = "${var.project_name}-otel-ssm-policy"
  description = "Allows ECS Execution Role to fetch OTel Collector config from SSM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = aws_ssm_parameter.otel_config.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "execution_ssm" {
  role       = data.aws_iam_role.execution_role.name
  policy_arn = aws_iam_policy.otel_ssm_policy.arn
}