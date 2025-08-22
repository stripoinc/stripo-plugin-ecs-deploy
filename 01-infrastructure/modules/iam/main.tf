resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.env_prefix}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role_policy.json
  tags = var.tags
}

data "aws_iam_policy_document" "ecs_task_execution_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs_execution_secrets" {
  name        = "ecs-execution-secrets"
  description = "Allow ECS execution role to read Docker Hub secret"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.docker_hub.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_secrets" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.ecs_execution_secrets.arn
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.env_prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role_policy.json
  tags = var.tags
}

# Docker Hub Secret
resource "aws_secretsmanager_secret" "docker_hub" {
  name                    = "${var.env_prefix}-docker-hub"
  description             = "Docker Hub credentials for Stripo Plugin ECS project"
  recovery_window_in_days = 0  # Force deletion without recovery period
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "docker_hub" {
  secret_id = aws_secretsmanager_secret.docker_hub.id
  secret_string = jsonencode({
    username = var.docker_hub_username
    password = var.docker_hub_password
  })
}

output "execution_role_arn" {
  value = aws_iam_role.ecs_task_execution.arn
}
output "task_role_arn" {
  value = aws_iam_role.ecs_task.arn
}
output "docker_hub_secret_arn" {
  value = aws_secretsmanager_secret.docker_hub.arn
} 