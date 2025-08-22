module "alb" {
  source = "./alb"
  
  vpc_id         = var.vpc_id
  env_prefix     = var.env_prefix
  public_subnets = var.public_subnets
  alb_sg_id      = var.alb_sg_id
  tags           = var.tags
  
  # HTTPS variables
  domain_name    = var.domain_name
  certificate_arn = var.certificate_arn
  enable_https   = var.enable_https
}

output "alb_arn" {
  value = module.alb.alb_arn
}
output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "security_group_id" {
  value = module.alb.security_group_id
}
output "listener_arn" {
  value = module.alb.listener_arn
}
output "https_listener_arn" {
  value = module.alb.https_listener_arn
} 