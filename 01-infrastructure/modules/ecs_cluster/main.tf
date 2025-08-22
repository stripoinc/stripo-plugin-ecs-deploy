resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = var.env_prefix
  description = "Private DNS namespace for ECS services"
  vpc         = var.vpc_id
  tags        = var.tags
}

resource "aws_ecs_cluster" "this" {
  name = "${var.env_prefix}-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  service_connect_defaults {
    namespace = aws_service_discovery_private_dns_namespace.this.arn
  }
  tags = var.tags
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
} 