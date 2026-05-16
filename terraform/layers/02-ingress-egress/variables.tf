variable "region" {
  description = "AWS Region"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC created in Layer 01"
  type        = string
}