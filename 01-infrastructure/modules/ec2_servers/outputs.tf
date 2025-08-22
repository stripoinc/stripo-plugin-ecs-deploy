output "postgresql_private_ip" {
  description = "Private IP of PostgreSQL instance"
  value       = aws_instance.postgresql.private_ip
}

output "postgresql_public_ip" {
  description = "Public IP of PostgreSQL instance"
  value       = aws_instance.postgresql.public_ip
}



output "redis_private_ip" {
  description = "Private IP of Redis instance"
  value       = var.enable_redis ? aws_instance.redis[0].private_ip : null
}

output "redis_public_ip" {
  description = "Public IP of Redis instance"
  value       = var.enable_redis ? aws_instance.redis[0].public_ip : ""
}

output "postgresql_sg_id" {
  description = "Security group ID for PostgreSQL"
  value       = aws_security_group.postgresql_sg.id
}



output "redis_sg_id" {
  description = "Security group ID for Redis"
  value       = var.enable_redis ? aws_security_group.redis_sg[0].id : null
}

output "ansible_key_name" {
  description = "Name of the SSH key pair for Ansible"
  value       = aws_key_pair.ansible_key.key_name
}

output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Private IP of bastion host"
  value       = aws_instance.bastion.private_ip
}

output "private_key_pem" {
  description = "Private key in PEM format"
  value       = local.keys_exist ? file(local.private_key_path) : tls_private_key.ansible_key[0].private_key_pem
  sensitive   = true
}

output "public_key_openssh" {
  description = "Public key in OpenSSH format"
  value       = local.keys_exist ? file(local.public_key_path) : tls_private_key.ansible_key[0].public_key_openssh
} 