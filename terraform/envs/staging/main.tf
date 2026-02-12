terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28.0"
    }
  }
  required_version = ">= 1.14.3"
}
provider "aws" {
  region = var.region
}

locals {
  environment = "staging"
  name_prefix = "${var.project_name}-${local.environment}"
}

module "iam" {
  source = "../../modules/iam"

  name_prefix          = local.name_prefix
  deployment_buckets   = var.deployment_buckets
  ssm_parameter_prefix = "/${var.project_name}/${local.environment}/"
}

module "network" {
  source = "../../modules/network"

  name_prefix       = local.name_prefix
  environment       = local.environment
  vpc_cidr          = var.vpc_cidr
  azs               = var.azs
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

module "ssm_human_access" {
  source = "../../modules/ssm-human-access"

  role_names  = var.ssm_human_role_names
  policy_name = "${local.name_prefix}-ssm-human-access"
}

module "rds" {
  source = "../../modules/rds"

  name_prefix          = local.name_prefix
  environment          = local.environment
  db_subnet_ids        = module.network.data_private_subnet_ids
  db_security_group_id = module.network.rds_security_group_id

  engine               = "mysql"
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  allocated_storage_gb = var.db_allocated_storage_gb

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  multi_az                = true
  backup_retention_period = 7
  deletion_protection     = false
  skip_final_snapshot     = true
}

data "aws_ssm_parameter" "ubuntu_2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.ubuntu_2404_ami.value
}

resource "aws_lb" "public" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.network.alb_security_group_id]
  subnets            = module.network.public_subnet_ids

  tags = {
    Environment = local.environment
  }
}

resource "aws_lb_target_group" "web" {
  name     = "${local.name_prefix}-web-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = module.network.vpc_id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_launch_template" "web" {
  name_prefix   = "${local.name_prefix}-web-"
  image_id      = local.ami_id
  instance_type = var.web_instance_type

  vpc_security_group_ids = [module.network.web_security_group_id]

  iam_instance_profile { name = module.iam.iam_instance_profile_name }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    sudo systemctl enable --now docker || true
    sudo docker rm -f web-nginx || true
    sudo docker run -d --restart=always --name web-nginx -p 3000:80 nginx:stable
  EOF
  )
}

resource "aws_autoscaling_group" "web" {
  name                = "${local.name_prefix}-web-asg"
  vpc_zone_identifier = module.network.web_private_subnet_ids

  min_size         = var.web_asg_min
  desired_capacity = var.web_asg_desired
  max_size         = var.web_asg_max

  health_check_type = "ELB"

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    triggers = ["launch_template"]

    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 60
    }
  }

  target_group_arns = [aws_lb_target_group.web.arn]
}

resource "aws_launch_template" "app_spring" {
  name_prefix   = "${local.name_prefix}-app-spring-"
  image_id      = local.ami_id
  instance_type = var.app_instance_type

  vpc_security_group_ids = [module.network.app_spring_security_group_id]

  iam_instance_profile { name = module.iam.iam_instance_profile_name }

  user_data = base64encode("#!/bin/bash\nset -e\n")
}

resource "aws_autoscaling_group" "app_spring" {
  name                = "${local.name_prefix}-app-spring-asg"
  vpc_zone_identifier = module.network.app_private_subnet_ids

  min_size         = var.app_spring_asg_min
  desired_capacity = var.app_spring_asg_desired
  max_size         = var.app_spring_asg_max

  launch_template {
    id      = aws_launch_template.app_spring.id
    version = aws_launch_template.app_spring.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    triggers = ["launch_template"]

    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 60
    }
  }
}

resource "aws_launch_template" "app_ai" {
  name_prefix   = "${local.name_prefix}-app-ai-"
  image_id      = local.ami_id
  instance_type = var.ai_instance_type

  vpc_security_group_ids = [module.network.app_ai_security_group_id]

  iam_instance_profile { name = module.iam.iam_instance_profile_name }

  user_data = base64encode("#!/bin/bash\nset -e\n")
}

resource "aws_autoscaling_group" "app_ai" {
  name                = "${local.name_prefix}-app-ai-asg"
  vpc_zone_identifier = module.network.app_private_subnet_ids

  min_size         = var.ai_asg_min
  desired_capacity = var.ai_asg_desired
  max_size         = var.ai_asg_max

  launch_template {
    id      = aws_launch_template.app_ai.id
    version = aws_launch_template.app_ai.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    triggers = ["launch_template"]

    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 60
    }
  }
}

output "alb_dns_name" { value = aws_lb.public.dns_name }
output "rds_endpoint" { value = module.rds.endpoint }
