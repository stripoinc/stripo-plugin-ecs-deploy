variable "env_prefix" {
  description = "Environment prefix for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where servers will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for server placement"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for bastion host"
  type        = list(string)
}

variable "ssh_access_cidr" {
  description = "CIDR block for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "ami_id" {
  description = "AMI ID for Ubuntu 22.04"
  type        = string
}

variable "bastion_instance_type" {
  description = "EC2 instance type for Bastion host"
  type        = string
}

variable "postgresql_instance_type" {
  description = "EC2 instance type for PostgreSQL"
  type        = string
}

variable "redis_instance_type" {
  description = "EC2 instance type for Redis"
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
}

variable "enable_redis" {
  description = "Whether to create Redis server"
  type        = bool
  default     = true
} 