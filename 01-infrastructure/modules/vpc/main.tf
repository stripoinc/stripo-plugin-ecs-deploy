# Get availability zones for the current region
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = var.env_prefix
  cidr = var.vpc_cidr
  azs             = var.azs != null ? var.azs : slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  enable_nat_gateway = true
  single_nat_gateway = true
  tags = var.tags
}

output "vpc_id" {
  value = module.vpc.vpc_id
} 