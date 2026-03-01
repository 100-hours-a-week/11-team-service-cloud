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
  environment = "prod"
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
  backup_retention_period = 14
  deletion_protection     = true
  skip_final_snapshot     = false
}

# S3 bucket for staging config/artifacts (docker-compose, etc.)
# NOTE: S3 bucket name 규칙상 underscore(_)는 사용할 수 없어서 하이픈(-)을 써야 함.
module "scuad_prod_config" {
  source = "../../modules/s3"

  bucket_name = var.s3_config_bucket_name

  # Defaults (documented for clarity)
  enable_versioning   = true
  force_destroy       = false
  sse_algorithm       = "AES256"
  block_public_access = true
}

# S3 bucket for staging app data (uploads, etc.)
module "scuad_prod" {
  source = "../../modules/s3"

  bucket_name = var.s3_app_bucket_name

  enable_versioning   = true
  force_destroy       = false
  sse_algorithm       = "AES256"
  block_public_access = true
}

# SSM Parameter for backend (.env)
# NOTE: We intentionally ignore value changes so you can update it safely in the AWS Console
# without Terraform overwriting it on the next apply.
resource "aws_ssm_parameter" "staging_be_dot_env" {
  name        = "/${var.project_name}/${local.environment}/be/DOT_ENV"
  description = "scuad prod backend .env"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE__"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Environment = local.environment
    Project     = var.project_name
  }
}

resource "aws_ssm_parameter" "staging_fe_dot_env" {
  name        = "/${var.project_name}/${local.environment}/fe/DOT_ENV"
  description = "scuad prod frontend .env"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE__"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Environment = local.environment
    Project     = var.project_name
  }
}

resource "aws_ssm_parameter" "staging_ai_dot_env" {
  name        = "/${var.project_name}/${local.environment}/ai/DOT_ENV"
  description = "scuad prod ai .env"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE__"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Environment = local.environment
    Project     = var.project_name
  }
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

# -------------------------
# Egress Proxy (public subnet)
# -------------------------
resource "aws_security_group" "egress_proxy" {
  count = var.enable_egress_proxy ? 1 : 0

  name        = "${local.name_prefix}-egress-proxy-sg"
  description = "Forward proxy in public subnet for private instances"
  vpc_id      = module.network.vpc_id

  ingress {
    description = "Proxy from VPC"
    from_port   = var.egress_proxy_port
    to_port     = var.egress_proxy_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-egress-proxy-sg"
    Environment = local.environment
  }
}

resource "aws_instance" "egress_proxy" {
  count = var.enable_egress_proxy ? 1 : 0

  ami                    = local.ami_id
  instance_type          = var.egress_proxy_instance_type
  subnet_id              = module.network.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.egress_proxy[0].id]

  associate_public_ip_address = true

  iam_instance_profile = module.iam.iam_instance_profile_name

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee -a /var/log/user-data.log) 2>&1

    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y squid

    # Write a full squid.conf to avoid rule-order issues with distro defaults
    cat >/etc/squid/squid.conf <<CONF
    http_port ${var.egress_proxy_port}

    # Client allowlist
    acl allowed_vpc src ${var.vpc_cidr}

    # Destination allowlist (domains)
    # Leading dot matches the domain and all subdomains.
    acl allowed_domains dstdomain ${join(" ", var.egress_proxy_allowed_domains)}

    # Ports hardening
    acl SSL_ports port 443
    acl Safe_ports port 80 443
    http_access deny !Safe_ports
    http_access deny CONNECT !SSL_ports

    # Allow only VPC -> allowed domains (CONNECT included)
    http_access allow allowed_vpc allowed_domains

    # Deny everything else
    http_access deny all

    # Basic hardening
    forwarded_for delete
    via off

    # Logs
    access_log /var/log/squid/access.log
    cache_log /var/log/squid/cache.log
    CONF

    systemctl enable --now squid
    systemctl restart squid
  EOF

  tags = {
    Name        = "${local.name_prefix}-egress-proxy"
    Environment = local.environment
  }
}

output "egress_proxy_public_ip" {
  value       = try(aws_instance.egress_proxy[0].public_ip, null)
  description = "Public IP of the egress proxy instance (if enabled)"
}

output "egress_proxy_private_ip" {
  value       = try(aws_instance.egress_proxy[0].private_ip, null)
  description = "Private IP of the egress proxy instance (if enabled)"
}

resource "aws_lb_target_group" "web" {
  name     = "${local.name_prefix}-web-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = module.network.vpc_id
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"

  # Reasonable modern default. Change if you have a compliance requirement.
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  # Always redirect HTTP -> HTTPS
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# - /api/* -> Spring (public ALB)
resource "aws_lb_listener_rule" "public_api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_spring_public.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# -------------------------
# Internal ALB (private service-to-service)
# -------------------------
resource "aws_lb" "internal" {
  name               = "${local.name_prefix}-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [module.network.internal_alb_security_group_id]
  subnets            = module.network.app_private_subnet_ids

  tags = {
    Environment = local.environment
  }
}

resource "aws_lb_target_group" "app_spring_internal" {
  name     = "${local.name_prefix}-app-spring-int-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.network.vpc_id

  health_check {
    path                = "/api/health"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

# NOTE: A target group can only be associated with *one* load balancer.
# We use separate target groups for public ALB and internal ALB.
resource "aws_lb_target_group" "app_spring_public" {
  name     = "${local.name_prefix}-app-spring-pub-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.network.vpc_id

  health_check {
    path                = "/api/health"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

resource "aws_lb_target_group" "app_ai_internal" {
  name     = "${local.name_prefix}-app-ai-int-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = module.network.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_spring_internal.arn
  }
}

resource "aws_lb_listener_rule" "internal_ai" {
  listener_arn = aws_lb_listener.internal_http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_ai_internal.arn
  }

  condition {
    path_pattern {
      values = ["/ai/*"]
    }
  }
}

resource "aws_lb_listener_rule" "internal_spring" {
  listener_arn = aws_lb_listener.internal_http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_spring_internal.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

output "rds_endpoint" { value = module.rds.endpoint }
