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
  environment = "dev"
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

  multi_az                = false
  backup_retention_period = 3
  deletion_protection     = false
  skip_final_snapshot     = true
}

# Ubuntu 24.04 AMI via SSM Parameter (region-safe)
data "aws_ssm_parameter" "ubuntu_2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.ubuntu_2404_ami.value
}

# -------------------------
# ALB (public)
# -------------------------
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

resource "aws_lb_target_group" "app_spring" {
  name     = "${local.name_prefix}-app-spring-tg"
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

resource "aws_lb_target_group" "app_ai" {
  name     = "${local.name_prefix}-app-ai-tg"
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

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Public ALB routing
# - /api/* -> Spring
resource "aws_lb_listener_rule" "public_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_spring.arn
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

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_spring.arn
  }
}

# Route /ai/* to AI target group
resource "aws_lb_listener_rule" "internal_ai" {
  listener_arn = aws_lb_listener.internal_http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_ai.arn
  }

  condition {
    path_pattern {
      values = ["/ai/*"]
    }
  }
}

# Route /api/* to Spring target group
resource "aws_lb_listener_rule" "internal_spring" {
  listener_arn = aws_lb_listener.internal_http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_spring.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# -------------------------
# Launch templates + ASGs
# -------------------------
resource "aws_launch_template" "web" {
  name_prefix   = "${local.name_prefix}-web-"
  image_id      = local.ami_id
  instance_type = var.web_instance_type

  vpc_security_group_ids = [module.network.web_security_group_id]

  iam_instance_profile {
    name = module.iam.iam_instance_profile_name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee -a /var/log/user-data.log) 2>&1

    systemctl enable --now docker

    timeout 60 bash -c 'until docker info >/dev/null 2>&1; do echo "Waiting for docker..."; sleep 1; done'

    aws ecr get-login-password --region ap-northeast-2 | \
      docker login --username AWS --password-stdin 209192769586.dkr.ecr.ap-northeast-2.amazonaws.com

    docker pull 209192769586.dkr.ecr.ap-northeast-2.amazonaws.com/scuad-frontend:dev-0.0.0

    docker rm -f scuad-frontend || true
    docker run -d --restart unless-stopped --name scuad-frontend -p 3000:3000 \
      209192769586.dkr.ecr.ap-northeast-2.amazonaws.com/scuad-frontend:dev-0.0.0
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${local.name_prefix}-web"
      Environment = local.environment
      Tier        = "web"
    }
  }
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
      # With desired_capacity=1, keep at least 0% healthy during refresh so replacement can proceed.
      min_healthy_percentage = 0
      instance_warmup        = 60
    }
  }

  target_group_arns = [aws_lb_target_group.web.arn]

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-web"
    propagate_at_launch = true
  }
}

resource "aws_launch_template" "app_spring" {
  name_prefix   = "${local.name_prefix}-app-spring-"
  image_id      = local.ami_id
  instance_type = var.app_instance_type

  vpc_security_group_ids = [module.network.app_spring_security_group_id]

  iam_instance_profile {
    name = module.iam.iam_instance_profile_name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee -a /var/log/user-data.log) 2>&1

    REGION="ap-northeast-2"
    APP_DIR="/opt/scuad"
    COMPOSE_S3_URI="s3://scuad-dev-config/be/docker-compose.yml"
    ENV_PARAM_NAME="/be/env/dev/DOT_ENV"
    ECR_REGISTRY="209192769586.dkr.ecr.$REGION.amazonaws.com"

    retry() {
      local n=0
      local max=10
      local delay=3
      until "$@"; do
        n=$((n + 1))
        if [ "$n" -ge "$max" ]; then
          echo "Command failed after $${max} attempts: $*" >&2
          return 1
        fi
        sleep "$delay"
      done
    }

    systemctl enable --now docker
    timeout 120 bash -c 'until docker info >/dev/null 2>&1; do echo "Waiting for docker..."; sleep 1; done'

    mkdir -p "$APP_DIR"
    cd "$APP_DIR"
    
    retry aws s3 cp "$COMPOSE_S3_URI" ./docker-compose.yml --region "$REGION"

    retry aws ssm get-parameter \
      --name "$ENV_PARAM_NAME" --with-decryption \
      --query "Parameter.Value" --output text --region "$REGION" > "$APP_DIR/.env"
    chmod 600 "$APP_DIR/.env" || true

    retry bash -lc "aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"

    retry docker compose pull
    docker compose up -d --remove-orphans
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${local.name_prefix}-app-spring"
      Environment = local.environment
      Tier        = "app"
      Role        = "spring"
    }
  }
}

resource "aws_autoscaling_group" "app_spring" {
  name                = "${local.name_prefix}-app-spring-asg"
  vpc_zone_identifier = module.network.app_private_subnet_ids

  min_size         = var.app_spring_asg_min
  desired_capacity = var.app_spring_asg_desired
  max_size         = var.app_spring_asg_max

  health_check_type = "ELB"

  launch_template {
    id      = aws_launch_template.app_spring.id
    version = aws_launch_template.app_spring.latest_version
  }

  target_group_arns = [aws_lb_target_group.app_spring.arn]

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

  iam_instance_profile {
    name = module.iam.iam_instance_profile_name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee -a /var/log/user-data.log) 2>&1

    systemctl enable --now docker

    timeout 60 bash -c 'until docker info >/dev/null 2>&1; do echo "Waiting for docker..."; sleep 1; done'

    aws ecr get-login-password --region ap-northeast-2 | \
      docker login --username AWS --password-stdin 209192769586.dkr.ecr.ap-northeast-2.amazonaws.com

    docker pull 209192769586.dkr.ecr.ap-northeast-2.amazonaws.com/scuad-ai:dev-0.1.0

    # Parameter Store에서 .env 가져오기
    aws ssm get-parameter --name "/ai/env/DEV_DOT_ENV" --with-decryption --query "Parameter.Value" --output text --region ap-northeast-2 > /home/ubuntu/.env

    docker rm -f scuad-ai || true
    docker run -d --restart unless-stopped --name scuad-ai -p 8000:8000 \
      --env-file /home/ubuntu/.env \
      209192769586.dkr.ecr.ap-northeast-2.amazonaws.com/scuad-ai:dev-0.1.0
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${local.name_prefix}-app-ai"
      Environment = local.environment
      Tier        = "app"
      Role        = "ai"
    }
  }
}

resource "aws_autoscaling_group" "app_ai" {
  name                = "${local.name_prefix}-app-ai-asg"
  vpc_zone_identifier = module.network.app_private_subnet_ids

  min_size         = var.ai_asg_min
  desired_capacity = var.ai_asg_desired
  max_size         = var.ai_asg_max

  health_check_type = "ELB"

  launch_template {
    id      = aws_launch_template.app_ai.id
    version = aws_launch_template.app_ai.latest_version
  }

  target_group_arns = [aws_lb_target_group.app_ai.arn]

  instance_refresh {
    strategy = "Rolling"
    triggers = ["launch_template"]

    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 60
    }
  }
}

output "alb_dns_name" {
  value = aws_lb.public.dns_name
}

output "internal_alb_dns_name" {
  value       = aws_lb.internal.dns_name
  description = "Internal ALB DNS name for service-to-service calls (VPC only)"
}

output "rds_endpoint" {
  value = module.rds.endpoint
}
