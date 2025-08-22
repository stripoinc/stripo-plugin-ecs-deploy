module "vpc" {
  source = "./modules/vpc"
  env_prefix      = var.env_prefix
  vpc_cidr        = var.vpc_cidr
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  tags            = var.tags
}

module "sg" {
  source     = "./modules/sg"
  env_prefix = var.env_prefix
  vpc_id     = module.vpc.vpc_id
  tags       = var.tags
}

module "iam" {
  source     = "./modules/iam"
  env_prefix = var.env_prefix
  tags       = var.tags
  
  # Docker Hub Configuration
  docker_hub_username = var.docker_hub_username
  docker_hub_password = var.docker_hub_password
}

module "s3" {
  source = "./modules/s3"
  
  env_prefix        = var.env_prefix
  tags              = var.tags
  ecs_task_role_arn = module.iam.task_role_arn
}

module "ecs_cluster" {
  source     = "./modules/ecs_cluster"
  env_prefix = var.env_prefix
  vpc_id     = module.vpc.vpc_id
  tags       = var.tags
}

module "alb" {
  source         = "./modules/alb"
  env_prefix     = var.env_prefix
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnet_ids
  alb_sg_id      = module.sg.alb_sg_id
  tags           = var.tags
  
  # HTTPS configuration
  domain_name    = var.domain_name
  certificate_arn = var.certificate_arn
  enable_https   = var.enable_https
}

module "ec2_servers" {
  source              = "./modules/ec2_servers"
  env_prefix          = var.env_prefix
  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = var.vpc_cidr
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids
  ssh_access_cidr     = var.ssh_access_cidr
  tags                = var.tags
  
  # EC2 Configuration
  ami_id                    = var.ami_id
  bastion_instance_type     = var.bastion_instance_type
  postgresql_instance_type  = var.postgresql_instance_type
  redis_instance_type       = var.redis_instance_type
  
  # Volume Configuration
  bastion_root_volume_size     = var.bastion_root_volume_size
  bastion_root_volume_type     = var.bastion_root_volume_type
  postgresql_root_volume_size  = var.postgresql_root_volume_size
  postgresql_root_volume_type  = var.postgresql_root_volume_type
  redis_root_volume_size       = var.redis_root_volume_size
  redis_root_volume_type       = var.redis_root_volume_type
  
  # Redis Configuration
  enable_redis                 = var.enable_redis
} 