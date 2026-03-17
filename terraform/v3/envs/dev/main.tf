locals {
  environment = "dev"
  name_prefix = "${var.project}-v3-${local.environment}"
}

# Shared VPC id (created in v3/envs/shared-network)
data "aws_ssm_parameter" "vpc_id" {
  name = var.vpc_id_ssm_param_name
}

# Lookup subnets by Name tag (created by v3/modules/vpc and tagged Name=<subnet name>)
data "aws_subnet" "alb_public_a" {
  filter {
    name   = "vpc-id"
    values = [data.aws_ssm_parameter.vpc_id.value]
  }

  filter {
    name   = "tag:Name"
    values = ["dev-public-a"]
  }
}

data "aws_subnet" "alb_public_b" {
  filter {
    name   = "vpc-id"
    values = [data.aws_ssm_parameter.vpc_id.value]
  }

  filter {
    name   = "tag:Name"
    values = ["dev-public-b"]
  }
}

data "aws_subnet" "workers_a" {
  filter {
    name   = "vpc-id"
    values = [data.aws_ssm_parameter.vpc_id.value]
  }

  filter {
    name   = "tag:Name"
    values = ["dev-private-app-a"]
  }
}

data "aws_subnet" "workers_b" {
  filter {
    name   = "vpc-id"
    values = [data.aws_ssm_parameter.vpc_id.value]
  }

  filter {
    name   = "tag:Name"
    values = ["dev-private-app-b"]
  }
}

module "kubeadm_public_alb_workers" {
  source = "../../modules/kubeadm-alb-asg"

  name_prefix = local.name_prefix
  environment = local.environment

  vpc_id              = data.aws_ssm_parameter.vpc_id.value
  public_subnet_ids   = [data.aws_subnet.alb_public_a.id, data.aws_subnet.alb_public_b.id]
  worker_subnet_ids   = [data.aws_subnet.workers_a.id, data.aws_subnet.workers_b.id]
  alb_certificate_arn = var.alb_certificate_arn

  nodeport_http     = var.nodeport_http
  health_check_path = var.health_check_path

  workers_min          = var.workers_min
  workers_desired      = var.workers_desired
  workers_max          = var.workers_max
  worker_instance_type = var.worker_instance_type

  ssh_key_name     = var.ssh_key_name
  worker_user_data = var.worker_user_data

  tags = {
    Project = var.project
  }
}

output "alb_dns_name" {
  value       = module.kubeadm_public_alb_workers.alb_dns_name
  description = "Public ALB DNS"
}

# -------------------------
# Data layer
# - RDS(MySQL)
# - Redis (EC2)
# - RabbitMQ (EC2)
# - Weaviate (EC2)
# -------------------------
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "RDS MySQL (dev)"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-sg"
    Tier = "data"
  })
}

resource "aws_security_group_rule" "rds_3306_from_workers" {
  type              = "ingress"
  security_group_id = aws_security_group.rds.id

  protocol  = "tcp"
  from_port = 3306
  to_port   = 3306

  source_security_group_id = module.kubeadm_public_alb_workers.workers_security_group_id
  description              = "MySQL from k8s workers"
}

module "rds_mysql" {
  source = "../../modules/rds-mysql"

  name_prefix   = "${local.name_prefix}-dev"
  environment   = local.environment
  db_subnet_ids = [data.aws_subnet.data_a.id, data.aws_subnet.data_b.id]

  db_security_group_id = aws_security_group.rds.id

  db_name     = "service_db"
  db_username = "scuad"
  db_password = var.db_password

  # dev defaults (tune later)
  instance_class          = "db.t4g.small"
  allocated_storage_gb    = 20
  backup_retention_period = 3
  deletion_protection     = false
  skip_final_snapshot     = true
}

# Common cloud-init for data service instances (Docker)
locals {
  data_service_user_data = {
    redis = <<-EOF
      #!/bin/bash
      set -euo pipefail
      exec > /var/log/user-data.log 2>&1
      set -x

      export DEBIAN_FRONTEND=noninteractive

      # Private subnets have no direct egress; route AWS API/Docker traffic via egress proxy
      export http_proxy="http://${module.egress_proxy.private_ip}:${var.egress_proxy_port}"
      export https_proxy="http://${module.egress_proxy.private_ip}:${var.egress_proxy_port}"
      export no_proxy="127.0.0.1,localhost,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,169.254.169.254,.cluster.local"

      REGION="${var.aws_region}"
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

      # Custom AMI is expected to have docker + docker compose plugin + awscli.
      systemctl enable --now docker || true

      # Ensure Docker daemon also uses the egress proxy (otherwise docker login/pull will timeout)
      mkdir -p /etc/systemd/system/docker.service.d
      cat >/etc/systemd/system/docker.service.d/http-proxy.conf <<CONF
      [Service]
      Environment="HTTP_PROXY=$http_proxy"
      Environment="HTTPS_PROXY=$https_proxy"
      Environment="NO_PROXY=$no_proxy"
      CONF
      systemctl daemon-reload
      systemctl restart docker
      timeout 120 bash -c 'until docker info >/dev/null 2>&1; do echo "Waiting for docker..."; sleep 1; done'

      mkdir -p "$APP_DIR"
      cd "$APP_DIR"

      retry aws s3 cp "$COMPOSE_S3_URI" ./docker-compose.yml --region "$REGION"

      # Login to ECR (even if compose uses public images, this is harmless)
      retry bash -lc "aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"

      retry docker compose pull
      docker compose up -d --remove-orphans
    EOF

    rabbitmq = <<-EOF
      #!/bin/bash
      set -euo pipefail
      exec > /var/log/user-data.log 2>&1
      set -x

      export DEBIAN_FRONTEND=noninteractive

      # Private subnets have no direct egress; route AWS API/Docker traffic via egress proxy
      export http_proxy="http://${module.egress_proxy.private_ip}:${var.egress_proxy_port}"
      export https_proxy="http://${module.egress_proxy.private_ip}:${var.egress_proxy_port}"
      export no_proxy="127.0.0.1,localhost,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,169.254.169.254,.cluster.local"

      REGION="${var.aws_region}"
      SERVICE="rabbitmq"
      APP_DIR="/opt/scuad/$SERVICE"
      COMPOSE_S3_URI="s3://scuad-dev-config/$SERVICE/docker-compose.yml"
      ECR_REGISTRY="209192769586.dkr.ecr.$REGION.amazonaws.com"

      # Requested defaults
      RABBITMQ_PORT=5672
      RABBITMQ_USERNAME=guest
      RABBITMQ_PASSWORD=guest

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

      # Custom AMI is expected to have docker + docker compose plugin + awscli.
      systemctl enable --now docker || true

      # Ensure Docker daemon also uses the egress proxy (otherwise docker login/pull will timeout)
      mkdir -p /etc/systemd/system/docker.service.d
      cat >/etc/systemd/system/docker.service.d/http-proxy.conf <<CONF
      [Service]
      Environment="HTTP_PROXY=$http_proxy"
      Environment="HTTPS_PROXY=$https_proxy"
      Environment="NO_PROXY=$no_proxy"
      CONF
      systemctl daemon-reload
      systemctl restart docker
      timeout 120 bash -c 'until docker info >/dev/null 2>&1; do echo "Waiting for docker..."; sleep 1; done'

      mkdir -p "$APP_DIR"
      cd "$APP_DIR"

      retry aws s3 cp "$COMPOSE_S3_URI" ./docker-compose.yml --region "$REGION"

      # Login to ECR (even if compose uses public images, this is harmless)
      retry bash -lc "aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"

      # Option A: pass defaults via env (compose file may choose to use them)
      export RABBITMQ_PORT RABBITMQ_USERNAME RABBITMQ_PASSWORD

      retry docker compose pull
      docker compose up -d --remove-orphans
    EOF

    weaviate = <<-EOF
      #!/bin/bash
      set -euo pipefail
      exec > /var/log/user-data.log 2>&1
      set -x

      export DEBIAN_FRONTEND=noninteractive

      # Private subnets have no direct egress; route AWS API/Docker traffic via egress proxy
      export http_proxy="http://${module.egress_proxy.private_ip}:${var.egress_proxy_port}"
      export https_proxy="http://${module.egress_proxy.private_ip}:${var.egress_proxy_port}"
      export no_proxy="127.0.0.1,localhost,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,169.254.169.254,.cluster.local"

      REGION="${var.aws_region}"
      SERVICE="weaviate"
      APP_DIR="/opt/scuad/$SERVICE"
      COMPOSE_S3_URI="s3://scuad-dev-config/$SERVICE/docker-compose.yml"
      ECR_REGISTRY="209192769586.dkr.ecr.$REGION.amazonaws.com"

      # Requested ports
      WEAVIATE_PORT=8080
      WEAVIATE_GRPC_PORT=50051

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

      # Custom AMI is expected to have docker + docker compose plugin + awscli.
      systemctl enable --now docker || true

      # Ensure Docker daemon also uses the egress proxy (otherwise docker login/pull will timeout)
      mkdir -p /etc/systemd/system/docker.service.d
      cat >/etc/systemd/system/docker.service.d/http-proxy.conf <<CONF
      [Service]
      Environment="HTTP_PROXY=$http_proxy"
      Environment="HTTPS_PROXY=$https_proxy"
      Environment="NO_PROXY=$no_proxy"
      CONF
      systemctl daemon-reload
      systemctl restart docker
      timeout 120 bash -c 'until docker info >/dev/null 2>&1; do echo "Waiting for docker..."; sleep 1; done'

      mkdir -p "$APP_DIR"
      cd "$APP_DIR"

      retry aws s3 cp "$COMPOSE_S3_URI" ./docker-compose.yml --region "$REGION"

      # Login to ECR (even if compose uses public images, this is harmless)
      retry bash -lc "aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"

      export WEAVIATE_PORT WEAVIATE_GRPC_PORT

      retry docker compose pull
      docker compose up -d --remove-orphans
    EOF
  }
}

module "redis" {
  source = "../../modules/service-ec2"

  name_prefix  = local.name_prefix
  environment  = local.environment
  service_name = "redis"

  vpc_id              = data.aws_ssm_parameter.vpc_id.value
  subnet_id           = data.aws_subnet.data_a.id
  ami_id              = "ami-0f72e4ed0f9238d39"
  instance_type       = "t3.small"
  root_volume_size_gb = 20

  ingress_from_security_group_id = module.kubeadm_public_alb_workers.workers_security_group_id
  ingress_ports                  = [6379]

  ssh_key_name = var.ssh_key_name
  user_data    = local.data_service_user_data.redis

  # Needed for fetching docker-compose.yml from S3 and pulling images from ECR
  s3_read_buckets     = ["scuad-dev-config"]
  enable_ecr_readonly = true

  tags = local.common_tags
}

module "rabbitmq" {
  source = "../../modules/service-ec2"

  name_prefix  = local.name_prefix
  environment  = local.environment
  service_name = "rabbitmq"

  vpc_id              = data.aws_ssm_parameter.vpc_id.value
  subnet_id           = data.aws_subnet.data_a.id
  ami_id              = "ami-0f72e4ed0f9238d39"
  instance_type       = "t3.small"
  root_volume_size_gb = 20

  ingress_from_security_group_id = module.kubeadm_public_alb_workers.workers_security_group_id
  ingress_ports                  = [5672]

  ssh_key_name = var.ssh_key_name
  user_data    = local.data_service_user_data.rabbitmq

  # Needed for fetching docker-compose.yml from S3 and pulling images from ECR
  s3_read_buckets     = ["scuad-dev-config"]
  enable_ecr_readonly = true

  tags = local.common_tags
}

module "weaviate" {
  source = "../../modules/service-ec2"

  name_prefix  = local.name_prefix
  environment  = local.environment
  service_name = "weaviate"

  vpc_id              = data.aws_ssm_parameter.vpc_id.value
  subnet_id           = data.aws_subnet.data_a.id
  ami_id              = "ami-0f72e4ed0f9238d39"
  instance_type       = "t3.small"
  root_volume_size_gb = 20

  ingress_from_security_group_id = module.kubeadm_public_alb_workers.workers_security_group_id
  ingress_ports                  = [8080, 50051]

  ssh_key_name = var.ssh_key_name
  user_data    = local.data_service_user_data.weaviate

  # Needed for fetching docker-compose.yml from S3 and pulling images from ECR
  s3_read_buckets     = ["scuad-dev-config"]
  enable_ecr_readonly = true

  tags = local.common_tags
}

output "rds_endpoint" {
  value       = module.rds_mysql.endpoint
  description = "RDS MySQL endpoint"
}

output "redis_private_ip" {
  value       = module.redis.private_ip
  description = "Redis private IP"
}

output "rabbitmq_private_ip" {
  value       = module.rabbitmq.private_ip
  description = "RabbitMQ private IP"
}

output "weaviate_private_ip" {
  value       = module.weaviate.private_ip
  description = "Weaviate private IP"
}

# Node-to-node connectivity rules (Calico + kubelet scrape)
module "k8s_node_connectivity" {
  source = "../../modules/k8s-node-connectivity"

  name_prefix         = local.name_prefix
  control_plane_sg_id = module.kubeadm_control_plane.security_group_id
  workers_sg_id       = module.kubeadm_public_alb_workers.workers_security_group_id

  # Pod CIDR supernet used by Calico (from kubeadm init config)
  pod_cidr = "192.168.0.0/16"
}

module "egress_proxy" {
  source = "../../modules/egress-proxy"

  name_prefix = local.name_prefix
  environment = local.environment
  vpc_id      = data.aws_ssm_parameter.vpc_id.value
  subnet_id   = data.aws_subnet.alb_public_a.id

  instance_type   = var.egress_proxy_instance_type
  proxy_port      = var.egress_proxy_port
  allow_all       = var.egress_proxy_allow_all
  allowed_domains = var.egress_proxy_allowed_domains

  ssh_key_name = var.ssh_key_name

  tags = {
    Project = var.project
  }
}

output "egress_proxy_public_ip" {
  value       = module.egress_proxy.public_ip
  description = "Public IP of egress proxy"
}

output "egress_proxy_private_ip" {
  value       = module.egress_proxy.private_ip
  description = "Private IP of egress proxy"
}

# -------------------------
# Golden AMI sample instances (dev)
# - Public subnet so package installs work without egress proxy.
# - Use SSM to access; SSH is optional.
# -------------------------
module "k8s_golden_ami_builder_worker" {
  source = "../../modules/k8s-golden-ami-builder"

  name_prefix = "${local.name_prefix}-k8s-worker"
  environment = local.environment
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  subnet_id = data.aws_subnet.alb_public_a.id

  instance_type     = var.ami_builder_instance_type
  ssh_key_name      = var.ssh_key_name
  allowed_ssh_cidrs = var.ami_builder_allowed_ssh_cidrs

  enable_proxy     = false
  proxy_private_ip = null
  proxy_port       = var.egress_proxy_port

  k8s_minor_version = var.k8s_minor_version
  helm_version      = var.helm_version
  pause_image       = var.pause_image

  tags = {
    Project = var.project
    Role    = "k8s-worker-ami-builder"
  }
}

module "k8s_golden_ami_builder_control_plane" {
  source = "../../modules/k8s-golden-ami-builder"

  name_prefix = "${local.name_prefix}-k8s-cp"
  environment = local.environment
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  subnet_id = data.aws_subnet.alb_public_a.id

  instance_type     = var.ami_builder_instance_type
  ssh_key_name      = var.ssh_key_name
  allowed_ssh_cidrs = var.ami_builder_allowed_ssh_cidrs

  enable_proxy     = false
  proxy_private_ip = null
  proxy_port       = var.egress_proxy_port

  k8s_minor_version = var.k8s_minor_version
  helm_version      = var.helm_version
  pause_image       = var.pause_image

  tags = {
    Project = var.project
    Role    = "k8s-control-plane-ami-builder"
  }
}

output "ami_builder_worker_instance_id" {
  value       = module.k8s_golden_ami_builder_worker.instance_id
  description = "Worker golden AMI sample instance id"
}

output "ami_builder_control_plane_instance_id" {
  value       = module.k8s_golden_ami_builder_control_plane.instance_id
  description = "Control plane golden AMI sample instance id"
}
