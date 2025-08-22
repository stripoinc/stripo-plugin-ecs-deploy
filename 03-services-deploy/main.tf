# Get current region
data "aws_region" "current" {}

# CloudWatch Log Groups

resource "aws_cloudwatch_log_group" "ai_service" {
  name              = "/ecs/plugin-ecs-v1-ai-service"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "amp_validator_service" {
  name              = "/ecs/plugin-ecs-v1-amp-validator-service"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/ecs/plugin-ecs-v1-api-gateway"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "countdowntimer" {
  name              = "/ecs/plugin-ecs-v1-countdowntimer"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "patches_service" {
  name              = "/ecs/plugin-ecs-v1-patches-service"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "proxy_service" {
  name              = "/ecs/plugin-ecs-v1-proxy-service"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "screenshot_service" {
  name              = "/ecs/plugin-ecs-v1-screenshot-service"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "stripe_html_cleaner_service" {
  name              = "/ecs/plugin-ecs-v1-stripe-html-cleaner-service"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "stripe_html_gen_service" {
  name              = "/ecs/plugin-ecs-v1-stripe-html-gen-service"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "stripo_plugin_custom_blocks_service" {
  name              = "/ecs/plugin-ecs-v1-stripo-plugin-custom-blocks-service"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "stripo_plugin_details_service" {
  name              = "/ecs/plugin-ecs-v1-stripo-plugin-details-service"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "stripo_plugin_documents_service" {
  name              = "/ecs/plugin-ecs-v1-stripo-plugin-documents-service"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "stripo_plugin_drafts_service" {
  name              = "/ecs/plugin-ecs-v1-stripo-plugin-drafts-service"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "stripo_plugin_image_bank_service" {
  name              = "/ecs/plugin-ecs-v1-stripo-plugin-image-bank-service"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "stripo_plugin_statistics_service" {
  name              = "/ecs/plugin-ecs-v1-stripo-plugin-statistics-service"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "stripo_security_service" {
  name              = "/ecs/plugin-ecs-v1-stripo-security-service"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "stripo_timer_api" {
  name              = "/ecs/plugin-ecs-v1-stripo-timer-api"
  retention_in_days = 7
  tags              = var.tags
}

# ALB Target Groups and Listener Rules

resource "aws_lb_target_group" "api_gateway" {
  name     = "api-gateway-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"
  health_check {
    path = "/version"
    protocol = "HTTP"
  }
  tags = var.tags
}

resource "aws_lb_listener_rule" "api_gateway" {
  listener_arn = var.https_listener_arn
  priority     = 999
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_gateway.arn
  }
  condition {
    path_pattern {
      values = [
  "/*"
]
    }
  }
}

resource "aws_lb_target_group" "countdowntimer" {
  name     = "countdowntimer-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"
  health_check {
    path = "/api/version"
    protocol = "HTTP"
  }
  tags = var.tags
}

resource "aws_lb_listener_rule" "countdowntimer" {
  listener_arn = var.https_listener_arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.countdowntimer.arn
  }
  condition {
    path_pattern {
      values = [
  "/api/v1/images/*",
  "/api-files/*",
  "/api-uploads/*",
  "/api/version"
]
    }
  }
}

resource "aws_lb_target_group" "proxy_service" {
  name     = "proxy-service-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"
  health_check {
    path = "/proxy/version"
    protocol = "HTTP"
  }
  tags = var.tags
}

resource "aws_lb_listener_rule" "proxy_service" {
  listener_arn = var.https_listener_arn
  priority     = 110
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.proxy_service.arn
  }
  condition {
    path_pattern {
      values = [
  "/plugin-proxy-service/*",
  "/proxy/*"
]
    }
  }
}

# ECS Services

module "ecs_service_ai_service" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-plugin-ai-service"
  cpu                   = 1024
  memory                = 2048
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-plugin-ai-service"
      image     = "stripo/ai-service:20250729-0547_5948398"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = [
  {
    "name": "JAVA_TOOL_OPTIONS",
    "value": "-Xss256k -Xms256m -Xmx512m -XX:ReservedCodeCacheSize=128M"
  },
  {
    "name": "SPRING_DATASOURCE_URL",
    "value": "jdbc:postgresql://10.10.101.186:5432/ai_service"
  },
  {
    "name": "SPRING_DATASOURCE_USERNAME",
    "value": "user_ai_service"
  },
  {
    "name": "SPRING_DATASOURCE_PASSWORD",
    "value": "password_ai_service"
  },
  {
    "name": "CHAT_GPT_MODEL",
    "value": "gpt-4o"
  },
  {
    "name": "CHAT_GPT_TEMPERATURE",
    "value": "1.0"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "SPRING_CLOUD_CONFIG_ENABLED",
    "value": "false"
  },
  {
    "name": "STRIPO_SECURITY_SERVICE_BASEURL",
    "value": "http://stripo-security-service.plugin-ecs-v1:8080"
  },
  {
    "name": "STRIPO_SECURITY_SERVICE_PASSWORDV2",
    "value": "secret"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-ai-service"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "ai_service"
          }
        }
    }
  ])
  service_name      = "stripo-plugin-ai-service"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = null
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-plugin-ai-service"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_amp_validator_service" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-plugin-amp-validator-service"
  cpu                   = 512
  memory                = 1024
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-plugin-amp-validator-service"
      image     = "stripo/amp-validator-service:20250728-2101_6203b8b"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 512
      memory    = 1024
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = []
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-amp-validator-service"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "amp_validator_service"
          }
        }
    }
  ])
  service_name      = "stripo-plugin-amp-validator-service"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = null
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-plugin-amp-validator-service"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_api_gateway" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-plugin-api-gateway"
  cpu                   = 2048
  memory                = 4096
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-plugin-api-gateway"
      image     = "stripo/stripo-plugin-api-gateway:20250729-0536_5948398"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 2048
      memory    = 4096
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = [
  {
    "name": "JAVA_TOOL_OPTIONS",
    "value": "-Xss256k -Xms400m -Xmx1536m -XX:ReservedCodeCacheSize=128M"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "JWT_SECRET_APIKEYV3",
    "value": "noKTwbyMQzenzkf8FQ/DpNZbN70mTwn5uwy2TC0IrBixeQAPCsTBF1b31IGAjdXsFM2IcLwKYnBJRKg2jNEQiw=="
  },
  {
    "name": "JWT_SECRET_EXPIRATIONINMINUTES",
    "value": "30"
  },
  {
    "name": "AUTH_INNERSERVICEPASSWORD",
    "value": "secret"
  },
  {
    "name": "SERVICE_TIMER_PASSWORD",
    "value": "secret"
  },
  {
    "name": "SERVICE_PLUGINDETAILS_URL",
    "value": "http://stripo-plugin-details-service.plugin-ecs-v1:8080"
  },
  {
    "name": "SERVICE_CUSTOMBLOCKS_URL",
    "value": "http://stripo-plugin-custom-blocks-service.plugin-ecs-v1:8080"
  },
  {
    "name": "SERVICE_DOCUMENTS_URL",
    "value": "http://stripo-plugin-documents-service.plugin-ecs-v1:8080"
  },
  {
    "name": "SERVICE_DRAFTS_URL",
    "value": "http://stripo-plugin-drafts-service.plugin-ecs-v1:8080"
  },
  {
    "name": "SERVICE_IMAGESBANK_URL",
    "value": "http://stripo-plugin-image-bank-service.plugin-ecs-v1:8080"
  },
  {
    "name": "SERVICE_HTMLGEN_URL",
    "value": "http://stripo-plugin-stripe-html-gen-service.plugin-ecs-v1:8080"
  },
  {
    "name": "SERVICE_HTMLCLEANER_URL",
    "value": "http://stripo-plugin-stripe-html-cleaner-service.plugin-ecs-v1:8080"
  },
  {
    "name": "SERVICE_STATISTICS_URL",
    "value": "http://stripo-plugin-statistics-service.plugin-ecs-v1:8080"
  },
  {
    "name": "SERVICE_TIMER_URL",
    "value": "http://stripo-timer-api.plugin-ecs-v1:8080"
  },
  {
    "name": "SERVICE_AI_URL",
    "value": "http://stripo-plugin-ai-service.plugin-ecs-v1:8080"
  },
  {
    "name": "RATE_LIMIT_ENABLED",
    "value": "false"
  },
  {
    "name": "REDISSON_URL",
    "value": "redis://:6379"
  },
  {
    "name": "REDISSON_PASSWORD",
    "value": "test"
  },
  {
    "name": "REDISSON_AUTHORIZED",
    "value": "true"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-api-gateway"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "api_gateway"
          }
        }
    }
  ])
  service_name      = "stripo-plugin-api-gateway"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = aws_lb_target_group.api_gateway.arn
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-plugin-api-gateway"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_countdowntimer" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-plugin-countdowntimer"
  cpu                   = 1024
  memory                = 2048
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-plugin-countdowntimer"
      image     = "stripo/countdowntimer:20250625-r1332_850b925_master"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
  {
    "containerPort": 80,
    "hostPort": 80
  }
]
      environment = [
  {
    "name": "APPNAME",
    "value": "countdowntimer"
  },
  {
    "name": "ENV",
    "value": "plugin-ecs-v1"
  },
  {
    "name": "PROFILE",
    "value": "plugin-ecs-v1"
  },
  {
    "name": "PROD",
    "value": "true"
  },
  {
    "name": "PLUGIN_PATCHES",
    "value": "true"
  },
  {
    "name": "AWS_SECRET_MANAGER",
    "value": "false"
  },
  {
    "name": "AWS_DEFAULT_REGION",
    "value": "us-east-1"
  },
  {
    "name": "AWS_REGION",
    "value": "us-east-1"
  },
  {
    "name": "DB_HOST",
    "value": "10.10.101.186"
  },
  {
    "name": "DB_PORT",
    "value": "5432"
  },
  {
    "name": "DB_NAME",
    "value": "countdowntimer"
  },
  {
    "name": "DB_USER",
    "value": "user_countdowntimer"
  },
  {
    "name": "DB_PASSWORD",
    "value": "password_countdowntimer"
  },
  {
    "name": "SECRET_KEY",
    "value": "H+5GkZL0hFsAhmDHyZr8zvKv0bhvXuBziV3FhKQ7loE="
  },
  {
    "name": "USE_HTTPS",
    "value": "true"
  },
  {
    "name": "GIF_URL",
    "value": "/api-files/"
  },
  {
    "name": "UPLOAD_URL",
    "value": "/api-uploads/"
  },
  {
    "name": "CACHE_LIFETIME",
    "value": "30"
  },
  {
    "name": "FONT_UPLOAD_FOLDER",
    "value": "/usr/local/countdowntimer/fonts"
  },
  {
    "name": "GIF_FOLDER",
    "value": "/opt/sources"
  },
  {
    "name": "UPLOAD_FOLDER",
    "value": "/opt/uploads"
  },
  {
    "name": "HOST",
    "value": "{{DOMAIN_NAME}}"
  },
  {
    "name": "CALLBACK_URL",
    "value": "https://dev-account.stripo.email/bapi/stripeapi/v1/timerevents"
  },
  {
    "name": "CALLBACK_USER",
    "value": "Admin"
  },
  {
    "name": "CALLBACK_PASSWORD",
    "value": "secret"
  },
  {
    "name": "CALLBACK_SOURCE",
    "value": "PLUGIN"
  },
  {
    "name": "SERVER_SERVLET_CONTEXT_PATH",
    "value": "/api"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-countdowntimer"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "countdowntimer"
          }
        }
    }
  ])
  service_name      = "stripo-plugin-countdowntimer"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = aws_lb_target_group.countdowntimer.arn
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-plugin-countdowntimer"
  container_port    = 80
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_patches_service" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-plugin-patches-service"
  cpu                   = 512
  memory                = 1024
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-plugin-patches-service"
      image     = "stripo/patches-service:20250728-2059_6203b8b"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 512
      memory    = 1024
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = [
  {
    "name": "NODE_OPTIONS",
    "value": "--max-old-space-size=900"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-patches-service"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "patches_service"
          }
        }
    }
  ])
  service_name      = "stripo-plugin-patches-service"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = null
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-plugin-patches-service"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_proxy_service" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-plugin-proxy-service"
  cpu                   = 1024
  memory                = 2048
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-plugin-proxy-service"
      image     = "stripo/stripo-plugin-proxy-service:20250728-2355_7f477f1"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = [
  {
    "name": "JAVA_TOOL_OPTIONS",
    "value": "-Xss256k -Xms256m -Xmx512m -XX:ReservedCodeCacheSize=128M"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "STRIPO_SECURITY_SERVICE_BASEURL",
    "value": "http://stripo-security-service.plugin-ecs-v1:8080"
  },
  {
    "name": "STRIPO_SECURITY_SERVICE_PASSWORDV2",
    "value": "secret"
  },
  {
    "name": "SERVER_SERVLET_CONTEXT_PATH",
    "value": "/proxy"
  },
  {
    "name": "SPRING_CLOUD_CONFIG_ENABLED",
    "value": "false"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-proxy-service"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "proxy_service"
          }
        }
    }
  ])
  service_name      = "stripo-plugin-proxy-service"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = aws_lb_target_group.proxy_service.arn
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-plugin-proxy-service"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_screenshot_service" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-plugin-screenshot-service"
  cpu                   = 1024
  memory                = 2048
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-plugin-screenshot-service"
      image     = "stripo/screenshot-service:20250728-2056_6203b8b"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = [
  {
    "name": "NODE_MEMORY",
    "value": "500"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-screenshot-service"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "screenshot_service"
          }
        }
    }
  ])
  service_name      = "stripo-plugin-screenshot-service"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = null
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-plugin-screenshot-service"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_stripe_html_cleaner_service" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-plugin-stripe-html-cleaner-service"
  cpu                   = 1024
  memory                = 2048
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-plugin-stripe-html-cleaner-service"
      image     = "stripo/stripe-html-cleaner-service:20250728-2354_7f477f1"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = [
  {
    "name": "JAVA_TOOL_OPTIONS",
    "value": "-Xss256k -Xms256m -Xmx512m -XX:ReservedCodeCacheSize=128M"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "AMP_VALIDATOR_ACTIVE",
    "value": "true"
  },
  {
    "name": "AMP_VALIDATOR_URL",
    "value": "http://stripo-plugin-amp-validator-service.plugin-ecs-v1:8080"
  },
  {
    "name": "SPRING_CLOUD_CONFIG_ENABLED",
    "value": "false"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-stripe-html-cleaner-service"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "stripe_html_cleaner_service"
          }
        }
    }
  ])
  service_name      = "stripo-plugin-stripe-html-cleaner-service"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = null
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-plugin-stripe-html-cleaner-service"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_stripe_html_gen_service" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-plugin-stripe-html-gen-service"
  cpu                   = 1024
  memory                = 2048
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-plugin-stripe-html-gen-service"
      image     = "stripo/stripe-html-gen-service:20250729-0001_7f477f1"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = [
  {
    "name": "JAVA_TOOL_OPTIONS",
    "value": "-Xss256k -Xms400m -Xmx512m -XX:MaxMetaspaceSize=256m -XX:-UseGCOverheadLimit -Djava.net.preferIPv4Stack=true"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "SPRING_DATASOURCE_URL",
    "value": "jdbc:postgresql://10.10.101.186:5432/stripo_plugin_local_html_gen"
  },
  {
    "name": "SPRING_DATASOURCE_USERNAME",
    "value": "user_html_gen"
  },
  {
    "name": "SPRING_DATASOURCE_PASSWORD",
    "value": "password_html_gen"
  },
  {
    "name": "STRIPO_SECURITY_SERVICE_BASEURL",
    "value": "http://stripo-security-service.plugin-ecs-v1:8080"
  },
  {
    "name": "STRIPO_SECURITY_SERVICE_PASSWORDV2",
    "value": "secret"
  },
  {
    "name": "RATE_LIMIT_ENABLED",
    "value": "false"
  },
  {
    "name": "SPRING_CLOUD_CONFIG_ENABLED",
    "value": "false"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-stripe-html-gen-service"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "stripe_html_gen_service"
          }
        }
    }
  ])
  service_name      = "stripo-plugin-stripe-html-gen-service"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = null
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-plugin-stripe-html-gen-service"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_stripo_plugin_custom_blocks_service" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-plugin-custom-blocks-service"
  cpu                   = 1024
  memory                = 2048
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-plugin-custom-blocks-service"
      image     = "stripo/stripo-plugin-custom-blocks-service:20250728-2356_7f477f1"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = [
  {
    "name": "JAVA_TOOL_OPTIONS",
    "value": "-Xss256k -Xms400m -Xmx512m -XX:ReservedCodeCacheSize=128M"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "SPRING_DATASOURCE_URL",
    "value": "jdbc:postgresql://10.10.101.186:5432/stripo_plugin_local_custom_blocks"
  },
  {
    "name": "SPRING_DATASOURCE_USERNAME",
    "value": "user_custom_blocks"
  },
  {
    "name": "SPRING_DATASOURCE_PASSWORD",
    "value": "password_custom_blocks"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "SPRING_CLOUD_CONFIG_ENABLED",
    "value": "false"
  },
  {
    "name": "PLUGIN_SERVICE_DOCUMENTSURL",
    "value": "http://stripo-plugin-documents-service.plugin-ecs-v1:8080"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-stripo-plugin-custom-blocks-service"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "stripo_plugin_custom_blocks_service"
          }
        }
    }
  ])
  service_name      = "stripo-plugin-custom-blocks-service"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = null
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-plugin-custom-blocks-service"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_stripo_plugin_details_service" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-plugin-details-service"
  cpu                   = 1024
  memory                = 2048
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-plugin-details-service"
      image     = "stripo/stripo-plugin-details-service:20250728-2107_6203b8b"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = [
  {
    "name": "JAVA_TOOL_OPTIONS",
    "value": "-Xss256k -Xms400m -Xmx512m -XX:ReservedCodeCacheSize=128M"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "SPRING_DATASOURCE_URL",
    "value": "jdbc:postgresql://10.10.101.186:5432/stripo_plugin_local_plugin_details"
  },
  {
    "name": "SPRING_DATASOURCE_USERNAME",
    "value": "user_plugin_details"
  },
  {
    "name": "SPRING_DATASOURCE_PASSWORD",
    "value": "password_plugin_details"
  },
  {
    "name": "STRIPO_SECURITY_SERVICE_BASEURL",
    "value": "http://stripo-security-service.plugin-ecs-v1:8080"
  },
  {
    "name": "STRIPO_SECURITY_SERVICE_PASSWORDV2",
    "value": "secret"
  },
  {
    "name": "SPRING_CLOUD_CONFIG_ENABLED",
    "value": "false"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-stripo-plugin-details-service"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "stripo_plugin_details_service"
          }
        }
    }
  ])
  service_name      = "stripo-plugin-details-service"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = null
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-plugin-details-service"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_stripo_plugin_documents_service" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-plugin-documents-service"
  cpu                   = 1024
  memory                = 2048
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-plugin-documents-service"
      image     = "stripo/stripo-plugin-documents-service:20250728-2356_7f477f1"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = [
  {
    "name": "JAVA_TOOL_OPTIONS",
    "value": "-Xss256k -Xms512m -Xmx2560m -XX:ReservedCodeCacheSize=128M"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "SPRING_DATASOURCE_URL",
    "value": "jdbc:postgresql://10.10.101.186:5432/stripo_plugin_local_documents"
  },
  {
    "name": "SPRING_DATASOURCE_USERNAME",
    "value": "user_documents"
  },
  {
    "name": "SPRING_DATASOURCE_PASSWORD",
    "value": "password_documents"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "SPRING_CLOUD_CONFIG_ENABLED",
    "value": "false"
  },
  {
    "name": "STORAGE_INTERNAL_AWS_ACCESSKEY",
    "value": "{{S3_ACCESS_KEY_ID}}"
  },
  {
    "name": "STORAGE_INTERNAL_AWS_SECRETKEY",
    "value": "{{S3_SECRET_ACCESS_KEY}}"
  },
  {
    "name": "STORAGE_INTERNAL_AWS_BUCKETNAME",
    "value": "plugin-ecs-v1-stripo-plugin-storage"
  },
  {
    "name": "STORAGE_INTERNAL_AWS_REGION",
    "value": "us-east-1"
  },
  {
    "name": "STORAGE_INTERNAL_AWS_BASEDOWNLOADURL",
    "value": "https://plugin-ecs-v1-stripo-plugin-storage.s3.us-east-1.amazonaws.com"
  },
  {
    "name": "PLUGIN_SERVICE_SCREENSHOTURL",
    "value": "http://stripo-plugin-screenshot-service.plugin-ecs-v1:8080"
  },
  {
    "name": "PLUGIN_SERVICE_PLUGINDETAILSURL",
    "value": "http://stripo-plugin-details-service.plugin-ecs-v1:8080"
  },
  {
    "name": "STRIPO_SECURITY_SERVICE_BASEURL",
    "value": "http://stripo-security-service.plugin-ecs-v1:8080"
  },
  {
    "name": "STRIPO_SECURITY_SERVICE_PASSWORDV2",
    "value": "secret"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-stripo-plugin-documents-service"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "stripo_plugin_documents_service"
          }
        }
    }
  ])
  service_name      = "stripo-plugin-documents-service"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = null
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-plugin-documents-service"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_stripo_plugin_drafts_service" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-plugin-drafts-service"
  cpu                   = 1024
  memory                = 2048
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-plugin-drafts-service"
      image     = "stripo/stripo-plugin-drafts-service:20250728-2352_7f477f1"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = [
  {
    "name": "JAVA_TOOL_OPTIONS",
    "value": "-Xss256k -Xms400m -Xmx512m -XX:ReservedCodeCacheSize=128M"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "SPRING_DATASOURCE_URL",
    "value": "jdbc:postgresql://10.10.101.186:5432/stripo_plugin_local_drafts"
  },
  {
    "name": "SPRING_DATASOURCE_USERNAME",
    "value": "user_drafts"
  },
  {
    "name": "SPRING_DATASOURCE_PASSWORD",
    "value": "password_drafts"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "SPRING_CLOUD_CONFIG_ENABLED",
    "value": "false"
  },
  {
    "name": "PLUGIN_SERVICE_PATCH_URL",
    "value": "http://stripo-plugin-patches-service.plugin-ecs-v1:8080"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-stripo-plugin-drafts-service"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "stripo_plugin_drafts_service"
          }
        }
    }
  ])
  service_name      = "stripo-plugin-drafts-service"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = null
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-plugin-drafts-service"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_stripo_plugin_image_bank_service" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-plugin-image-bank-service"
  cpu                   = 1024
  memory                = 2048
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-plugin-image-bank-service"
      image     = "stripo/stripo-plugin-image-bank-service:20250728-2355_7f477f1"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = [
  {
    "name": "JAVA_TOOL_OPTIONS",
    "value": "-Xss256k -Xms400m -Xmx512m -XX:ReservedCodeCacheSize=128M"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "SPRING_DATASOURCE_URL",
    "value": "jdbc:postgresql://10.10.101.186:5432/stripo_plugin_local_bank_images"
  },
  {
    "name": "SPRING_DATASOURCE_USERNAME",
    "value": "user_bank_images"
  },
  {
    "name": "SPRING_DATASOURCE_PASSWORD",
    "value": "password_bank_images"
  },
  {
    "name": "SPRING_CLOUD_CONFIG_ENABLED",
    "value": "false"
  },
  {
    "name": "PLUGIN_SERVICE_DOCUMENTS_URL",
    "value": "http://stripo-plugin-documents-service.plugin-ecs-v1:8080"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-stripo-plugin-image-bank-service"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "stripo_plugin_image_bank_service"
          }
        }
    }
  ])
  service_name      = "stripo-plugin-image-bank-service"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = null
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-plugin-image-bank-service"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_stripo_plugin_statistics_service" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-plugin-statistics-service"
  cpu                   = 1024
  memory                = 2048
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-plugin-statistics-service"
      image     = "stripo/stripo-plugin-statistics-service:20250728-2354_7f477f1"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = [
  {
    "name": "JAVA_TOOL_OPTIONS",
    "value": "-Xss256k -Xms400m -Xmx512m -XX:ReservedCodeCacheSize=128M"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "SPRING_DATASOURCE_URL",
    "value": "jdbc:postgresql://10.10.101.186:5432/stripo_plugin_local_plugin_stats"
  },
  {
    "name": "SPRING_DATASOURCE_USERNAME",
    "value": "user_plugin_stats"
  },
  {
    "name": "SPRING_DATASOURCE_PASSWORD",
    "value": "password_plugin_stats"
  },
  {
    "name": "SPRING_CLOUD_CONFIG_ENABLED",
    "value": "false"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-stripo-plugin-statistics-service"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "stripo_plugin_statistics_service"
          }
        }
    }
  ])
  service_name      = "stripo-plugin-statistics-service"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = null
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-plugin-statistics-service"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_stripo_security_service" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-security-service"
  cpu                   = 1024
  memory                = 2048
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-security-service"
      image     = "stripo/stripo-security-service:20250728-2107_6203b8b"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = [
  {
    "name": "JAVA_TOOL_OPTIONS",
    "value": "-Xss256k -Xms128m -Xmx256m -XX:ReservedCodeCacheSize=128M"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "SPRING_DATASOURCE_URL",
    "value": "jdbc:postgresql://10.10.101.186:5432/stripo_plugin_local_securitydb"
  },
  {
    "name": "SPRING_DATASOURCE_USERNAME",
    "value": "user_securitydb"
  },
  {
    "name": "SPRING_DATASOURCE_PASSWORD",
    "value": "password_securitydb"
  },
  {
    "name": "AUTH_PASSWORDV2",
    "value": "secret"
  },
  {
    "name": "SPRING_CLOUD_CONFIG_ENABLED",
    "value": "false"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-stripo-security-service"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "stripo_security_service"
          }
        }
    }
  ])
  service_name      = "stripo-security-service"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = null
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-security-service"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}

module "ecs_service_stripo_timer_api" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "stripo-timer-api"
  cpu                   = 1024
  memory                = 2048
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "stripo-timer-api"
      image     = "stripo/stripo-timer-api:20250728-2123_6203b8b"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
  {
    "containerPort": 8080,
    "hostPort": 8080
  }
]
      environment = [
  {
    "name": "APPNAME",
    "value": "stripo-timer-api"
  },
  {
    "name": "ENV",
    "value": "plugin-ecs-v1"
  },
  {
    "name": "PROFILE",
    "value": "plugin-ecs-v1"
  },
  {
    "name": "SPRING_CONFIG_NAME",
    "value": "base,application"
  },
  {
    "name": "SPRING_CONFIG_LOCATION",
    "value": "optional:classpath:/,optional:file:/config/"
  },
  {
    "name": "JVM_MEMORY_OPTS",
    "value": "-Dspring.cloud.config.enabled=false -Daws.secretsmanager.enabled=false"
  },
  {
    "name": "JAVA_TOOL_OPTIONS",
    "value": "-Xss256k -Xms256m -Xmx512m -XX:ReservedCodeCacheSize=128M"
  },
  {
    "name": "AWS_SECRET_MANAGER",
    "value": "false"
  },
  {
    "name": "AWS_DEFAULT_REGION",
    "value": "us-east-1"
  },
  {
    "name": "AWS_REGION",
    "value": "us-east-1"
  },
  {
    "name": "SPRING_CLOUD_CONFIG_ENABLED",
    "value": "false"
  },
  {
    "name": "SPRING_CLOUD_CONFIG_IMPORT_CHECK_ENABLED",
    "value": "false"
  },
  {
    "name": "SPRING_FLYWAY_BASELINE_ON_MIGRATE",
    "value": "true"
  },
  {
    "name": "SPRING_ZIPKIN_ENABLED",
    "value": "false"
  },
  {
    "name": "PLUGIN_PATCHES",
    "value": "true"
  },
  {
    "name": "LOGGING_LEVEL_ROOT",
    "value": "INFO"
  },
  {
    "name": "SPRING_DATASOURCE_URL",
    "value": "jdbc:postgresql://10.10.101.186:5432/stripo_plugin_local_timers"
  },
  {
    "name": "SPRING_DATASOURCE_USERNAME",
    "value": "user_timers"
  },
  {
    "name": "SPRING_DATASOURCE_PASSWORD",
    "value": "password_timers"
  },
  {
    "name": "TIMER_URL",
    "value": "http://stripo-plugin-countdowntimer.plugin-ecs-v1:80/api/"
  },
  {
    "name": "TIMER_USERNAME",
    "value": "Admin"
  },
  {
    "name": "TIMER_PASSWORD",
    "value": "secret"
  },
  {
    "name": "SPRING_SECURITY_USER_NAME",
    "value": "security-service"
  },
  {
    "name": "SPRING_SECURITY_USER_PASSWORDV2",
    "value": "secret"
  }
]
      linuxParameters = {
        initProcessEnabled = true
      }
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.env_prefix}-stripo-timer-api"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "stripo_timer_api"
          }
        }
    }
  ])
  service_name      = "stripo-timer-api"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = null
  alb_listener_arn  = var.https_listener_arn
  container_name    = "stripo-timer-api"
  container_port    = 8080
  desired_count     = 1
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}
