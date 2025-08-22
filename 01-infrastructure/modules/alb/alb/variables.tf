variable "vpc_id" {
  description = "VPC ID for the ALB."
  type        = string
}

variable "env_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet IDs."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID for the ALB."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

variable "domain_name" {
  description = "Domain name for the ALB (e.g., your-domain.example.com)."
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS."
  type        = string
  default     = ""
}

variable "enable_https" {
  description = "Enable HTTPS listener with SSL certificate."
  type        = bool
  default     = false
} 