resource "aws_ecs_task_definition" "this" {
  family                   = var.family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions    = var.container_definitions
  tags                     = var.tags
}

resource "aws_service_discovery_service" "this" {
  count = var.cloud_map_namespace_id != null ? 1 : 0
  name  = var.service_name
  dns_config {
    namespace_id = var.cloud_map_namespace_id
    dns_records {
      type = "A"
      ttl  = 10
    }
    routing_policy = "MULTIVALUE"
  }

}

resource "aws_ecs_service" "this" {
  name                    = var.service_name
  cluster                 = var.cluster_id
  task_definition         = aws_ecs_task_definition.this.arn
  desired_count           = var.desired_count
  launch_type             = "FARGATE"
  enable_execute_command  = true
  network_configuration {
    subnets          = var.subnets
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }
  dynamic "load_balancer" {
    for_each = var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }
  dynamic "service_registries" {
    for_each = var.cloud_map_namespace_id != null ? [1] : []
    content {
      registry_arn = aws_service_discovery_service.this[0].arn
      # port removed for A-record service discovery
    }
  }
  depends_on = [var.alb_listener_arn]
  tags       = var.tags
} 