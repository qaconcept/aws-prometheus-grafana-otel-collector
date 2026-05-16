provider "aws" {
  region = var.region
}

locals {
  name = var.project_name
}

# EFS File System
resource "aws_efs_file_system" "monitoring_data" {
  creation_token = "${local.name}-efs"
  encrypted      = true

  tags = { Name = "${local.name}-efs" }
}

# EFS Security Group: Only allow ECS Tasks to talk to EFS
resource "aws_security_group" "efs_sg" {
  name        = "${local.name}-efs-sg"
  description = "Allow EFS traffic from ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS from ECS"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.ecs_tasks_security_group_id]
  }

  tags = { Name = "${local.name}-efs-sg" }
}

# Mount Targets (One per Private Subnet for HA)
resource "aws_efs_mount_target" "monitoring" {
  count           = length(var.private_subnets)
  file_system_id  = aws_efs_file_system.monitoring_data.id
  subnet_id       = var.private_subnets[count.index]
  security_groups = [aws_security_group.efs_sg.id]
}

# Access Points for specific services to maintain path isolation
resource "aws_efs_access_point" "prometheus" {
  file_system_id = aws_efs_file_system.monitoring_data.id
  posix_user {
    gid = 1000
    uid = 1000
  }
  root_directory {
    path = "/prometheus"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }
}

resource "aws_efs_access_point" "grafana" {
  file_system_id = aws_efs_file_system.monitoring_data.id
  posix_user {
    gid = 472
    uid = 472
  }
  root_directory {
    path = "/grafana"
    creation_info {
      owner_gid   = 472
      owner_uid   = 472
      permissions = "755"
    }
  }
}