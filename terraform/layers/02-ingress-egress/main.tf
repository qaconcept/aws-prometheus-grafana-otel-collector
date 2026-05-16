provider "aws" {
  region = var.region
}

locals {
  name = var.project_name
}

# ALB Security Group: The only public entry point
resource "aws_security_group" "alb_sg" {
  name        = "${local.name}-alb-sg"
  description = "Allow TLS inbound traffic only"
  vpc_id      = var.vpc_id

  # HTTPS Ingress: Only Port 443 allowed per "Zero HTTP" requirement
  ingress {
    description      = "HTTPS from everywhere"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # Egress: Allow all outbound to reach backend services in private subnets
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "${local.name}-alb-sg" }
}

# ECS Task Security Group: Private backend layer
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "${local.name}-ecs-tasks-sg"
  description = "Allow inbound traffic from ALB only"
  vpc_id      = var.vpc_id

  # Ingress: Restrict source to the ALB Security Group ID
  ingress {
    description     = "Traffic from ALB only"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Egress: Allow all outbound (Required for pulling images and AWS API calls)
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "${local.name}-ecs-tasks-sg" }
}