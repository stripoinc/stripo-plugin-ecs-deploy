# Check if SSH keys exist
locals {
  ssh_keys_path = "${path.root}/ssh_keys"
  private_key_path = "${local.ssh_keys_path}/stripo-ansible-key"
  public_key_path = "${local.ssh_keys_path}/stripo-ansible-key.pub"
  keys_exist = fileexists(local.public_key_path)
}

# IAM Role for EC2 instances with Session Manager support
resource "aws_iam_role" "ec2_role" {
  name = "${var.env_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.env_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Attach SSM Managed Instance Core policy for Session Manager
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch Agent policy for logging
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Generate SSH Key Pair only if keys don't exist
resource "tls_private_key" "ansible_key" {
  count     = local.keys_exist ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

# SSH Key Pair
resource "aws_key_pair" "ansible_key" {
  key_name   = "${var.env_prefix}-ansible-key"
  public_key = local.keys_exist ? file(local.public_key_path) : tls_private_key.ansible_key[0].public_key_openssh
  
  tags = var.tags
  
  lifecycle {
    ignore_changes = [public_key]
  }
}

# Bastion Host Security Group
resource "aws_security_group" "bastion_sg" {
  name_prefix = "${var.env_prefix}-bastion-sg"
  vpc_id      = var.vpc_id
  description = "Bastion host access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_access_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.env_prefix}-bastion-sg"
  })
}

# Bastion Host
resource "aws_instance" "bastion" {
  ami                    = var.ami_id
  instance_type          = var.bastion_instance_type
  key_name               = aws_key_pair.ansible_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.bastion_root_volume_size
    volume_type = var.bastion_root_volume_type
  }

  tags = merge(var.tags, {
    Name = "${var.env_prefix}-bastion"
    Role = "bastion"
  })
  
  lifecycle {
    ignore_changes = [ami, instance_type]
  }
}

# Security Groups
resource "aws_security_group" "postgresql_sg" {
  name_prefix = "${var.env_prefix}-postgresql-sg"
  vpc_id      = var.vpc_id
  description = "PostgreSQL access"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.env_prefix}-postgresql-sg"
  })
}

resource "aws_security_group" "redis_sg" {
  count       = var.enable_redis ? 1 : 0
  name_prefix = "${var.env_prefix}-redis-sg"
  vpc_id      = var.vpc_id
  description = "Redis access"

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.env_prefix}-redis-sg"
  })
}

# EC2 Instances
resource "aws_instance" "postgresql" {
  ami                    = var.ami_id
  instance_type          = var.postgresql_instance_type
  key_name               = aws_key_pair.ansible_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.postgresql_sg.id]

  root_block_device {
    volume_size = var.postgresql_root_volume_size
    volume_type = var.postgresql_root_volume_type
  }

  tags = merge(var.tags, {
    Name = "${var.env_prefix}-postgresql"
    Role = "postgresql"
  })
  
  lifecycle {
    ignore_changes = [ami, instance_type]
  }
}

resource "aws_instance" "redis" {
  count                   = var.enable_redis ? 1 : 0
  ami                     = var.ami_id
  instance_type           = var.redis_instance_type
  key_name                = aws_key_pair.ansible_key.key_name
  iam_instance_profile    = aws_iam_instance_profile.ec2_profile.name
  subnet_id               = var.private_subnet_ids[0]
  vpc_security_group_ids  = [aws_security_group.redis_sg[0].id]

  root_block_device {
    volume_size = var.redis_root_volume_size
    volume_type = var.redis_root_volume_type
  }

  tags = merge(var.tags, {
    Name = "${var.env_prefix}-redis"
    Role = "redis"
  })
  
  lifecycle {
    ignore_changes = [ami, instance_type]
  }
} 