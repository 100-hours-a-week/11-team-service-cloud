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

# NOTE: A target group can only be associated with *one* load balancer.
# We use separate target groups for public ALB and internal ALB.
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

  # If HTTPS is configured, force HTTPS for all internet traffic.
  # Otherwise, keep serving HTTP (useful before ACM cert is ready).
  dynamic "default_action" {
    for_each = var.alb_certificate_arn == null ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.web.arn
    }
  }

  dynamic "default_action" {
    for_each = var.alb_certificate_arn == null ? [] : [1]
    content {
      type = "redirect"

      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

# - /api/* -> Spring (HTTP only; disabled once HTTPS redirect is enabled)
resource "aws_lb_listener_rule" "public_api_http" {
  count = var.alb_certificate_arn == null ? 1 : 0

  listener_arn = aws_lb_listener.http.arn
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

# HTTPS listener (optional; created only when alb_certificate_arn is set)
resource "aws_lb_listener" "https" {
  count = var.alb_certificate_arn == null ? 0 : 1

  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# - /api/* -> Spring (HTTPS)
resource "aws_lb_listener_rule" "public_api_https" {
  count = var.alb_certificate_arn == null ? 0 : 1

  listener_arn = aws_lb_listener.https[0].arn
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

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_spring_internal.arn
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
    target_group_arn = aws_lb_target_group.app_spring_internal.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
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
    # (default config may contain a blanket "http_access deny all" before conf.d includes)
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

  target_group_arns = [
    aws_lb_target_group.app_spring_internal.arn,
    aws_lb_target_group.app_spring_public.arn,
  ]

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

# -------------------------
# Data services (standalone EC2; no ASG)
# -------------------------

resource "aws_security_group" "redis" {
  name        = "${local.name_prefix}-redis-sg"
  description = "Redis access (from app security groups)"
  vpc_id      = module.network.vpc_id

  ingress {
    description     = "Redis from Spring"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.network.app_spring_security_group_id]
  }

  ingress {
    description     = "Redis from AI"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.network.app_ai_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-redis-sg"
    Environment = local.environment
  }
}

resource "aws_instance" "redis" {
  ami                    = local.ami_id
  instance_type          = "t3.small"
  subnet_id              = module.network.data_private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.redis.id]

  iam_instance_profile = module.iam.iam_instance_profile_name

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee -a /var/log/user-data.log) 2>&1

    export DEBIAN_FRONTEND=noninteractive

    REGION="${var.region}"
    SERVICE="redis"
    APP_DIR="/opt/scuad/$SERVICE"
    COMPOSE_S3_URI="s3://scuad-dev-config/$SERVICE/docker-compose.yml"
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

    # Custom AMI pre-bakes docker + docker compose plugin + awscli
    systemctl enable --now docker || true
    timeout 120 bash -c 'until docker info >/dev/null 2>&1; do echo "Waiting for docker..."; sleep 1; done'

    mkdir -p "$APP_DIR"
    cd "$APP_DIR"

    retry aws s3 cp "$COMPOSE_S3_URI" ./docker-compose.yml --region "$REGION"

    retry bash -lc "aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"

    retry docker compose pull
    docker compose up -d --remove-orphans
  EOF

  tags = {
    Name        = "${local.name_prefix}-redis"
    Environment = local.environment
    Role        = "redis"
    Tier        = "data"
  }
}

resource "aws_security_group" "rabbitmq" {
  name        = "${local.name_prefix}-rabbitmq-sg"
  description = "RabbitMQ access (from app security groups)"
  vpc_id      = module.network.vpc_id

  ingress {
    description     = "AMQP from Spring"
    from_port       = 5672
    to_port         = 5672
    protocol        = "tcp"
    security_groups = [module.network.app_spring_security_group_id]
  }

  ingress {
    description     = "AMQP from AI"
    from_port       = 5672
    to_port         = 5672
    protocol        = "tcp"
    security_groups = [module.network.app_ai_security_group_id]
  }

  # Optional: RabbitMQ Management UI (15672) from SSH allowlist CIDRs (if provided)
  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "RabbitMQ management UI (allowed SSH CIDRs)"
      from_port   = 15672
      to_port     = 15672
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-rabbitmq-sg"
    Environment = local.environment
  }
}

resource "aws_instance" "rabbitmq" {
  ami                    = local.ami_id
  instance_type          = "t3.small"
  subnet_id              = module.network.data_private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.rabbitmq.id]

  iam_instance_profile = module.iam.iam_instance_profile_name

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee -a /var/log/user-data.log) 2>&1

    export DEBIAN_FRONTEND=noninteractive

    REGION="${var.region}"
    SERVICE="rabbitmq"
    APP_DIR="/opt/scuad/$SERVICE"
    COMPOSE_S3_URI="s3://scuad-dev-config/$SERVICE/docker-compose.yml"
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

    # Custom AMI pre-bakes docker + docker compose plugin + awscli
    systemctl enable --now docker || true
    timeout 120 bash -c 'until docker info >/dev/null 2>&1; do echo "Waiting for docker..."; sleep 1; done'

    mkdir -p "$APP_DIR"
    cd "$APP_DIR"

    retry aws s3 cp "$COMPOSE_S3_URI" ./docker-compose.yml --region "$REGION"

    retry bash -lc "aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"

    retry docker compose pull
    docker compose up -d --remove-orphans
  EOF

  # Slightly larger root volume is usually helpful for queues/logs.
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name        = "${local.name_prefix}-rabbitmq"
    Environment = local.environment
    Role        = "rabbitmq"
    Tier        = "data"
  }
}

resource "aws_security_group" "weaviate" {
  name        = "${local.name_prefix}-weaviate-sg"
  description = "Weaviate access (from app security groups)"
  vpc_id      = module.network.vpc_id

  ingress {
    description     = "Weaviate HTTP from Spring"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [module.network.app_spring_security_group_id]
  }

  ingress {
    description     = "Weaviate HTTP from AI"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [module.network.app_ai_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-weaviate-sg"
    Environment = local.environment
  }
}

resource "aws_instance" "weaviate" {
  ami                    = local.ami_id
  instance_type          = "t3.small"
  subnet_id              = module.network.data_private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.weaviate.id]

  iam_instance_profile = module.iam.iam_instance_profile_name

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee -a /var/log/user-data.log) 2>&1

    export DEBIAN_FRONTEND=noninteractive

    REGION="${var.region}"
    SERVICE="weaviate"
    APP_DIR="/opt/scuad/$SERVICE"
    COMPOSE_S3_URI="s3://scuad-dev-config/$SERVICE/docker-compose.yml"
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

    # Custom AMI pre-bakes docker + docker compose plugin + awscli
    systemctl enable --now docker || true
    timeout 120 bash -c 'until docker info >/dev/null 2>&1; do echo "Waiting for docker..."; sleep 1; done'

    mkdir -p "$APP_DIR"
    cd "$APP_DIR"

    retry aws s3 cp "$COMPOSE_S3_URI" ./docker-compose.yml --region "$REGION"

    retry bash -lc "aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"

    retry docker compose pull
    docker compose up -d --remove-orphans
  EOF

  # Vector DB tends to need disk headroom.
  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name        = "${local.name_prefix}-weaviate"
    Environment = local.environment
    Role        = "weaviate"
    Tier        = "data"
  }
}

output "redis_private_ip" {
  value       = aws_instance.redis.private_ip
  description = "Private IP for Redis instance"
}

output "rabbitmq_private_ip" {
  value       = aws_instance.rabbitmq.private_ip
  description = "Private IP for RabbitMQ instance"
}

output "weaviate_private_ip" {
  value       = aws_instance.weaviate.private_ip
  description = "Private IP for Weaviate instance"
}

output "rds_endpoint" {
  value = module.rds.endpoint
}
