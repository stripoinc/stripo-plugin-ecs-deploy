variable "cluster_id" {
  description = "ECS Cluster name or ARN."
  type        = string
}

variable "family" {
  description = "Task definition family."
  type        = string
}

variable "cpu" {
  description = "CPU units for the task."
  type        = string
}

variable "memory" {
  description = "Memory for the task."
  type        = string
}

variable "execution_role_arn" {
  description = "IAM execution role ARN."
  type        = string
}

variable "task_role_arn" {
  description = "IAM task role ARN."
  type        = string
}

variable "container_definitions" {
  description = "JSON string of container definitions."
  type        = string
}

variable "service_name" {
  description = "ECS service name."
  type        = string
}

variable "subnets" {
  description = "List of subnet IDs for the service."
  type        = list(string)
}

variable "ecs_sg_id" {
  description = "Security group ID for ECS tasks."
  type        = string
}

variable "target_group_arn" {
  description = "Target group ARN for ALB."
  type        = string
}

variable "container_name" {
  description = "Container name for load balancer."
  type        = string
}

variable "container_port" {
  description = "Container port for load balancer."
  type        = number
}

variable "alb_listener_arn" {
  description = "ALB listener ARN."
  type        = string
}

variable "desired_count" {
  description = "Desired number of tasks."
  type        = number
}

variable "tags" {
  description = "A map of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

variable "cloud_map_namespace_arn" {
  description = "ARN of the Cloud Map namespace for service discovery."
  type        = string
  default     = null
}

variable "cloud_map_namespace_id" {
  description = "ID of the Cloud Map namespace for service discovery."
  type        = string
  default     = null
} 