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

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "List of availability zones. If not specified, will be automatically determined from aws_region."
  type        = list(string)
  default     = null
}

variable "public_subnets" {
  description = "List of public subnet CIDRs."
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet CIDRs."
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to assign to all resources."
  type        = map(string)
}

variable "ssh_access_cidr" {
  description = "CIDR block for SSH access to EC2 instances"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the ALB (e.g., your-domain.example.com)."
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS."
  type        = string
}

variable "enable_https" {
  description = "Enable HTTPS listener with SSL certificate."
  type        = bool
}

# EC2 Servers Configuration
variable "ami_id" {
  description = "AMI ID for Ubuntu 22.04 LTS"
  type        = string
}

variable "bastion_instance_type" {
  description = "EC2 instance type for Bastion host"
  type        = string
}

variable "postgresql_instance_type" {
  description = "EC2 instance type for PostgreSQL server"
  type        = string
}

variable "redis_instance_type" {
  description = "EC2 instance type for Redis server"
  type        = string
}

# Volume Configuration
variable "bastion_root_volume_size" {
  description = "Root volume size in GB for Bastion host"
  type        = number
}

variable "bastion_root_volume_type" {
  description = "Root volume type for Bastion host"
  type        = string
}

variable "postgresql_root_volume_size" {
  description = "Root volume size in GB for PostgreSQL server"
  type        = number
}

variable "postgresql_root_volume_type" {
  description = "Root volume type for PostgreSQL server"
  type        = string
}

variable "redis_root_volume_size" {
  description = "Root volume size in GB for Redis server"
  type        = number
}

variable "redis_root_volume_type" {
  description = "Root volume type for Redis server"
  type        = string
  default     = "gp3"
}

variable "enable_redis" {
  description = "Whether to create Redis server"
  type        = bool
  default     = true
}

# Docker Hub Configuration
variable "docker_hub_username" {
  description = "Docker Hub username"
  type        = string
}

variable "docker_hub_password" {
  description = "Docker Hub password"
  type        = string
  sensitive   = true
}