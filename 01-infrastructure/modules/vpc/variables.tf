variable "env_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "List of availability zones."
  type        = list(string)
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
  default     = {}
} 