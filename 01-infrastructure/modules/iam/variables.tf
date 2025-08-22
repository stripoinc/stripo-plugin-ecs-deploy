variable "env_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

variable "docker_hub_username" {
  description = "Docker Hub username"
  type        = string
}

variable "docker_hub_password" {
  description = "Docker Hub password"
  type        = string
  sensitive   = true
} 