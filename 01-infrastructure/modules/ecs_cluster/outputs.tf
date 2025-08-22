output "cloud_map_namespace_arn" {
  value = aws_service_discovery_private_dns_namespace.this.arn
}
output "cloud_map_namespace_id" {
  value = aws_service_discovery_private_dns_namespace.this.id
} 