variable "vpc_id" {
  description = "VPC ID for the security groups."
  type        = string
}

variable "env_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to all resources."
  type        = map(string)
  default     = {}
} 