variable "region" { type = string }
variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "domain_name" { type = string }
variable "alb_security_group_id" { type = string }
variable "ecs_tasks_security_group_id" { type = string }
variable "ecs_task_execution_role_arn" { type = string }
variable "ecs_task_role_arn" { type = string }

# NEW: Toggle for Certificate Creation
variable "create_ssl_cert" {
  description = "Set to true to create a new ACM cert, false to use the existing one"
  type        = bool
  default     = false
}