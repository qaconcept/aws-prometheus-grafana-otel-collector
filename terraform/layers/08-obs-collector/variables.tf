variable "region" { type = string }
variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnets" { type = list(string) }
variable "ecs_tasks_security_group_id" { type = string }
variable "ecs_task_execution_role_arn" { type = string }
variable "ecs_task_role_arn" { type = string }
variable "ecs_cluster_id" { type = string }