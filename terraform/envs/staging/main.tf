terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28.0"
    }
  }
  required_version = ">= 1.14.3"

  backend "s3" {
    bucket         = "scuad-tfstate-ap-northeast-2"
    key            = "envs/staging/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "scuad-tfstate-lock"
    encrypt        = true
  }
}
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  environment = "staging"
  name_prefix = "${var.project_name}-${local.environment}"

  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

module "iam" {
  source = "../../modules/iam"

  name_prefix        = local.name_prefix
  deployment_buckets = var.deployment_buckets

  # Parameter Store path prefix that EC2 instances are allowed to read.
  # We keep this environment-scoped so user_data can read the .env securely.
  ssm_parameter_prefix = "/${local.environment}/"
}

module "network" {
  source = "../../modules/network"

  name_prefix               = local.name_prefix
  environment               = local.environment
  vpc_cidr                  = var.vpc_cidr
  azs                       = var.azs
  allowed_ssh_cidrs         = var.allowed_ssh_cidrs
  node_exporter_cidr_blocks = [var.dev_vpc_cidr]
}

module "ssm_human_access" {
  source = "../../modules/ssm-human-access"

  role_names  = var.ssm_human_role_names
  policy_name = "${local.name_prefix}-ssm-human-access"
}

module "rds" {
  source = "../../modules/rds"
  count  = var.enable_rds ? 1 : 0

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

# S3 bucket for staging config/artifacts (docker-compose, etc.)
# NOTE: S3 bucket name 규칙상 underscore(_)는 사용할 수 없어서 하이픈(-)을 써야 함.
module "scuad_staging_config" {
  source = "../../modules/s3"

  bucket_name = var.s3_config_bucket_name

  # Defaults (documented for clarity)
  enable_versioning   = true
  force_destroy       = false
  sse_algorithm       = "AES256"
  block_public_access = true
}

# S3 bucket for staging app data (uploads, etc.)
module "scuad_staging" {
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
  name        = "/staging/be/DOT_ENV"
  description = "scuad staging backend .env"
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
  name        = "/staging/fe/DOT_ENV"
  description = "scuad staging frontend .env"
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
  name        = "/staging/ai/DOT_ENV"
  description = "scuad staging ai .env"
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

  ingress {
    description = "Node Exporter from Dev VPC (monitoring)"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.dev_vpc_cidr]
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

resource "aws_launch_template" "web" {
  name_prefix   = "${local.name_prefix}-web-"
  image_id      = local.ami_id
  instance_type = var.web_instance_type

  vpc_security_group_ids = [module.network.web_security_group_id]

  iam_instance_profile { name = module.iam.iam_instance_profile_name }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee -a /var/log/user-data.log) 2>&1

    REGION="${var.region}"
    ECR_REGISTRY="${local.ecr_registry}"

    ENV_PARAM_NAME="/staging/fe/DOT_ENV"
    APP_DIR="/opt/scuad"

    FE_IMAGE="$ECR_REGISTRY/${var.ecr_fe_repo}:${var.ecr_image_tag}"

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
    timeout 60 bash -c 'until docker info >/dev/null 2>&1; do echo "Waiting for docker..."; sleep 1; done'

    mkdir -p "$APP_DIR"

    retry bash -lc "aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"

    retry docker pull "$FE_IMAGE"

    docker rm -f scuad-frontend || true
    docker run -d --restart unless-stopped --name scuad-frontend \
      -p 3000:3000 \
      "$FE_IMAGE"
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

  iam_instance_profile { name = module.iam.iam_instance_profile_name }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee -a /var/log/user-data.log) 2>&1

    REGION="${var.region}"
    APP_DIR="/opt/scuad"
    COMPOSE_S3_URI="s3://${var.s3_config_bucket_name}/be/docker-compose.yml"
    ENV_PARAM_NAME="/staging/be/DOT_ENV"
    ECR_REGISTRY="${local.ecr_registry}"

    BE_IMAGE="$ECR_REGISTRY/${var.ecr_be_repo}:${var.ecr_image_tag}"

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

    # Ensure backend image exists locally (compose should also reference main-latest)
    retry docker pull "$BE_IMAGE"

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

  instance_refresh {
    strategy = "Rolling"
    triggers = ["launch_template"]

    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 60
    }
  }

  target_group_arns = [
    aws_lb_target_group.app_spring_internal.arn,
    aws_lb_target_group.app_spring_public.arn,
  ]
}

resource "aws_launch_template" "app_ai" {
  name_prefix   = "${local.name_prefix}-app-ai-"
  image_id      = local.ami_id
  instance_type = var.ai_instance_type

  # Root volume size override (AMI default is not a hard limit)
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  vpc_security_group_ids = [module.network.app_ai_security_group_id]

  iam_instance_profile { name = module.iam.iam_instance_profile_name }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee -a /var/log/user-data.log) 2>&1

    REGION="${var.region}"
    ECR_REGISTRY="${local.ecr_registry}"

    ENV_PARAM_NAME="/staging/ai/DOT_ENV"
    APP_DIR="/opt/scuad"

    AI_IMAGE="$ECR_REGISTRY/${var.ecr_ai_repo}:${var.ecr_image_tag}"

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
    timeout 60 bash -c 'until docker info >/dev/null 2>&1; do echo "Waiting for docker..."; sleep 1; done'

    mkdir -p "$APP_DIR"

    retry aws ssm get-parameter \
      --name "$ENV_PARAM_NAME" --with-decryption \
      --query "Parameter.Value" --output text --region "$REGION" > "$APP_DIR/.env"
    chmod 600 "$APP_DIR/.env" || true

    retry bash -lc "aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"

    retry docker pull "$AI_IMAGE"

    docker rm -f scuad-ai || true
    docker run -d --restart unless-stopped --name scuad-ai \
      --env-file "$APP_DIR/.env" \
      -p 8000:8000 \
      "$AI_IMAGE"
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

  instance_refresh {
    strategy = "Rolling"
    triggers = ["launch_template"]

    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 60
    }
  }

  target_group_arns = [aws_lb_target_group.app_ai_internal.arn]
}

# --- Auto Scaling policies (Target Tracking) ---
# Keeps average ASG CPU utilization near the target value.
# NOTE: min/desired/max are still controlled by the ASG vars.

resource "aws_autoscaling_policy" "web_cpu_70" {
  name                   = "${local.name_prefix}-web-cpu-70"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }
}

resource "aws_autoscaling_policy" "app_spring_cpu_70" {
  name                   = "${local.name_prefix}-app-spring-cpu-70"
  autoscaling_group_name = aws_autoscaling_group.app_spring.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }
}

resource "aws_autoscaling_policy" "app_ai_cpu_70" {
  name                   = "${local.name_prefix}-app-ai-cpu-70"
  autoscaling_group_name = aws_autoscaling_group.app_ai.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }
}

output "alb_dns_name" { value = aws_lb.public.dns_name }
output "rds_endpoint" { value = var.enable_rds ? module.rds[0].endpoint : null }

output "s3_config_bucket_name" {
  description = "S3 bucket name for staging config/artifacts"
  value       = module.scuad_staging_config.bucket_name
}

output "s3_app_bucket_name" {
  description = "S3 bucket name for staging app data"
  value       = module.scuad_staging.bucket_name
}
