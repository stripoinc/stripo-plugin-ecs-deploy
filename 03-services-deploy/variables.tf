variable "aws_profile" {
  description = "AWS profile to use for authentication. Region will be automatically determined from this profile."
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy resources in. If not specified, will be determined from aws_profile."
  type        = string
  default     = null
}

variable "env_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS Cluster Name (output from infrastructure project)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (output from infrastructure project)"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs (output from infrastructure project)"
  type        = list(string)
}

variable "alb_arn" {
  description = "ALB ARN (output from infrastructure project)"
  type        = string
}



variable "alb_listener_arn" {
  description = "ALB Listener ARN (output from infrastructure project)"
  type        = string
}

variable "https_listener_arn" {
  description = "ALB HTTPS Listener ARN (output from infrastructure project)"
  type        = string
}

variable "ecs_services" {
  description = "Map of ECS service settings."
  type = map(object({
    image_repo    = string
    image_tag     = string
    cpu           = number
    memory        = number
    desired_count = number
    environment   = list(object({ name = string, value = string }))
  }))
  default = {}
}

variable "tags" {
  description = "A map of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

variable "execution_role_arn" {
  description = "IAM Execution Role ARN (output from infrastructure project)"
  type        = string
}

variable "task_role_arn" {
  description = "IAM Task Role ARN (output from infrastructure project)"
  type        = string
}

variable "ecs_sg_id" {
  description = "ECS Security Group ID (output from infrastructure project)"
  type        = string
}

variable "cloud_map_namespace_id" {
  description = "Cloud Map Namespace ID (output from infrastructure project)"
  type        = string
}

variable "dockerhub_secret_arn" {
  description = "ARN of secret with Docker Hub credentials (AWS Secrets Manager)"
  type        = string
} 