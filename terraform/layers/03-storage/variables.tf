variable "region" {
  description = "AWS Region"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from Layer 01"
  type        = string
}

variable "private_subnets" {
  description = "Private subnets from Layer 01"
  type        = list(string)
}

variable "ecs_tasks_security_group_id" {
  description = "ECS Tasks SG ID from Layer 02"
  type        = string
}