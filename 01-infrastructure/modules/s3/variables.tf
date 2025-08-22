variable "env_prefix" {
  description = "Environment prefix for resource naming"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "ecs_task_role_arn" {
  description = "ARN of the ECS Task Role for S3 access"
  type        = string
}
