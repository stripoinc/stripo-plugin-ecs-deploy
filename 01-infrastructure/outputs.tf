output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "ecs_cluster_name" {
  value = module.ecs_cluster.ecs_cluster_name
}

output "alb_arn" {
  value = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "listener_arn" {
  value = module.alb.listener_arn
}

output "https_listener_arn" {
  description = "HTTPS Listener ARN for ALB"
  value       = module.alb.https_listener_arn
}

output "execution_role_arn" {
  value = module.iam.execution_role_arn
}

output "task_role_arn" {
  value = module.iam.task_role_arn
}

output "docker_hub_secret_arn" {
  description = "ARN of Docker Hub secret in Secrets Manager"
  value       = module.iam.docker_hub_secret_arn
}

output "ecs_sg_id" {
  value = module.sg.ecs_sg_id
}

output "cloud_map_namespace_id" {
  value = module.ecs_cluster.cloud_map_namespace_id
}

# EC2 Servers outputs
output "postgresql_private_ip" {
  description = "Private IP of PostgreSQL instance"
  value       = module.ec2_servers.postgresql_private_ip
}

output "postgresql_public_ip" {
  description = "Public IP of PostgreSQL instance"
  value       = module.ec2_servers.postgresql_public_ip
}



output "redis_private_ip" {
  description = "Private IP of Redis instance"
  value       = module.ec2_servers.redis_private_ip
}

output "redis_public_ip" {
  description = "Public IP of Redis instance"
  value       = module.ec2_servers.redis_public_ip
}

# Bastion Host outputs
output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = module.ec2_servers.bastion_public_ip
}

output "bastion_private_ip" {
  description = "Private IP of bastion host"
  value       = module.ec2_servers.bastion_private_ip
}

output "private_key_pem" {
  description = "Private key in PEM format"
  value       = module.ec2_servers.private_key_pem
  sensitive   = true
}

output "public_key_openssh" {
  description = "Public key in OpenSSH format"
  value       = module.ec2_servers.public_key_openssh
}

# S3 Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket for Stripo Plugin storage"
  value       = module.s3.bucket_name
}

output "s3_bucket_region" {
  description = "Region of the S3 bucket"
  value       = module.s3.bucket_region
}

output "s3_base_download_url" {
  description = "Base download URL for S3 objects"
  value       = module.s3.base_download_url
}

output "s3_access_key_id" {
  description = "Access Key ID for S3 access"
  value       = module.s3.access_key_id
  sensitive   = true
}

output "s3_secret_access_key" {
  description = "Secret Access Key for S3 access"
  value       = module.s3.secret_access_key
  sensitive   = true
}

output "s3_website_endpoint" {
  description = "S3 website endpoint"
  value       = module.s3.website_endpoint
}

output "s3_website_domain" {
  description = "S3 website domain"
  value       = module.s3.website_domain
}

output "env_prefix" {
  description = "Environment prefix used for resource naming"
  value       = var.env_prefix
}

output "domain_name" {
  description = "Domain name for the application"
  value       = var.domain_name
}

output "tags" {
  description = "Tags used for all resources"
  value       = var.tags
} 