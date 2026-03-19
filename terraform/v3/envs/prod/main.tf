locals {
  environment = "prod"
  name_prefix = "${var.project}-v3-${local.environment}"
}

data "aws_ssm_parameter" "vpc_id" {
  name = var.vpc_id_ssm_param_name
}

data "aws_subnet" "alb_public_a" {
  filter {
    name   = "vpc-id"
    values = [data.aws_ssm_parameter.vpc_id.value]
  }

  filter {
    name   = "tag:Name"
    values = ["prod-public-a"]
  }
}

data "aws_subnet" "alb_public_b" {
  filter {
    name   = "vpc-id"
    values = [data.aws_ssm_parameter.vpc_id.value]
  }

  filter {
    name   = "tag:Name"
    values = ["prod-public-b"]
  }
}

data "aws_subnet" "workers_a" {
  filter {
    name   = "vpc-id"
    values = [data.aws_ssm_parameter.vpc_id.value]
  }

  filter {
    name   = "tag:Name"
    values = ["prod-private-app-a"]
  }
}

data "aws_subnet" "workers_b" {
  filter {
    name   = "vpc-id"
    values = [data.aws_ssm_parameter.vpc_id.value]
  }

  filter {
    name   = "tag:Name"
    values = ["prod-private-app-b"]
  }
}

# Private data subnets (for RDS/Redis/RabbitMQ/Weaviate)
data "aws_subnet" "data_a" {
  filter {
    name   = "vpc-id"
    values = [data.aws_ssm_parameter.vpc_id.value]
  }

  filter {
    name   = "tag:Name"
    values = ["prod-private-data-a"]
  }
}

data "aws_subnet" "data_b" {
  filter {
    name   = "vpc-id"
    values = [data.aws_ssm_parameter.vpc_id.value]
  }

  filter {
    name   = "tag:Name"
    values = ["prod-private-data-b"]
  }
}

module "kubeadm_control_plane" {
  source = "../../modules/kubeadm-control-plane-nodes"

  name_prefix = local.name_prefix
  environment = local.environment

  vpc_id     = data.aws_ssm_parameter.vpc_id.value
  subnet_ids = [data.aws_subnet.workers_a.id, data.aws_subnet.workers_b.id]
  replicas   = var.control_plane_replicas

  ami_id        = var.control_plane_ami_id
  instance_type = var.control_plane_instance_type

  ssh_key_name      = var.ssh_key_name
  allowed_ssh_cidrs = []

  allowed_api_cidrs = var.control_plane_allowed_api_cidrs
  control_plane_user_data = templatefile("${path.module}/control-plane-user-data.sh.tftpl", {
    region                                        = "ap-northeast-2"
    control_plane_endpoint                        = module.kubeadm_control_plane_endpoint.dns_name
    kubeadm_control_plane_endpoint_ssm_param_name = var.kubeadm_control_plane_endpoint_ssm_param_name
    kubeadm_join_token_ssm_param_name             = var.kubeadm_join_token_ssm_param_name
    kubeadm_ca_hash_ssm_param_name                = var.kubeadm_ca_hash_ssm_param_name

    http_proxy  = "http://${module.egress_proxy.endpoint_dns_name}:${var.egress_proxy_port}"
    https_proxy = "http://${module.egress_proxy.endpoint_dns_name}:${var.egress_proxy_port}"
    no_proxy    = local.no_proxy

    sandbox_image = "registry.k8s.io/pause:3.10"
  })

  # Allow CP to publish kubeadm join materials into SSM Parameter Store (optional)
  ssm_put_parameter_names = [
    var.kubeadm_control_plane_endpoint_ssm_param_name,
    var.kubeadm_join_token_ssm_param_name,
    var.kubeadm_ca_hash_ssm_param_name,
  ]

  tags = {
    Project = var.project
  }
}

module "kubeadm_control_plane_endpoint" {
  source = "../../modules/kubeadm-control-plane-endpoint-nlb"

  name_prefix = local.name_prefix
  environment = local.environment

  vpc_id     = data.aws_ssm_parameter.vpc_id.value
  subnet_ids = [data.aws_subnet.workers_a.id, data.aws_subnet.workers_b.id]
  internal   = true

  target_instance_ids = module.kubeadm_control_plane.instance_ids

  tags = {
    Project = var.project
  }
}

output "control_plane_instance_ids" {
  value       = module.kubeadm_control_plane.instance_ids
  description = "Control plane instance ids"
}

output "control_plane_private_ips" {
  value       = module.kubeadm_control_plane.private_ips
  description = "Control plane private IPs"
}

output "control_plane_internal_endpoint" {
  value       = module.kubeadm_control_plane_endpoint.dns_name
  description = "Internal NLB DNS name for kube-apiserver (6443)"
}

module "egress_proxy" {
  source = "../../modules/egress-proxy"

  name_prefix = local.name_prefix
  environment = local.environment
  vpc_id      = data.aws_ssm_parameter.vpc_id.value
  subnet_ids  = [data.aws_subnet.alb_public_a.id, data.aws_subnet.alb_public_b.id]
  enable_nlb  = true

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
# Data layer
# - RDS(MySQL)
# - Redis (EC2)
# - RabbitMQ (EC2)
# - Weaviate (EC2)
# -------------------------
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "RDS MySQL (prod)"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project
    Name    = "${local.name_prefix}-rds-sg"
    Tier    = "data"
  }
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

  name_prefix   = "${local.name_prefix}-prod"
  environment   = local.environment
  db_subnet_ids = [data.aws_subnet.data_a.id, data.aws_subnet.data_b.id]

  db_security_group_id = aws_security_group.rds.id

  db_name     = "service_db"
  db_username = "scuad"
  db_password = var.db_password

  # prod defaults (tune later)
  instance_class          = "db.t4g.small"
  allocated_storage_gb    = 20
  backup_retention_period = 7
  deletion_protection     = true
  skip_final_snapshot     = false
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
      COMPOSE_S3_URI="s3://scuad-prod-config/$SERVICE/docker-compose.yml"
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

      export http_proxy="http://${module.egress_proxy.private_ip}:${var.egress_proxy_port}"
      export https_proxy="http://${module.egress_proxy.private_ip}:${var.egress_proxy_port}"
      export no_proxy="127.0.0.1,localhost,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,169.254.169.254,.cluster.local"

      REGION="${var.aws_region}"
      SERVICE="rabbitmq"
      APP_DIR="/opt/scuad/$SERVICE"
      COMPOSE_S3_URI="s3://scuad-prod-config/$SERVICE/docker-compose.yml"
      ECR_REGISTRY="209192769586.dkr.ecr.$REGION.amazonaws.com"

      # TODO: set real credentials (do not keep guest/guest for prod)
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

      systemctl enable --now docker || true

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
      retry bash -lc "aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"

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

      export http_proxy="http://${module.egress_proxy.private_ip}:${var.egress_proxy_port}"
      export https_proxy="http://${module.egress_proxy.private_ip}:${var.egress_proxy_port}"
      export no_proxy="127.0.0.1,localhost,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,169.254.169.254,.cluster.local"

      REGION="${var.aws_region}"
      SERVICE="weaviate"
      APP_DIR="/opt/scuad/$SERVICE"
      COMPOSE_S3_URI="s3://scuad-prod-config/$SERVICE/docker-compose.yml"
      ECR_REGISTRY="209192769586.dkr.ecr.$REGION.amazonaws.com"

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

      systemctl enable --now docker || true

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
  ami_id              = var.data_service_ami_id
  instance_type       = "t3.small"
  root_volume_size_gb = 20

  ingress_from_security_group_id = module.kubeadm_public_alb_workers.workers_security_group_id
  ingress_ports                  = [6379]

  ssh_key_name = var.ssh_key_name
  user_data    = local.data_service_user_data.redis

  s3_read_buckets     = ["scuad-prod-config"]
  enable_ecr_readonly = true

  tags = {
    Project = var.project
    Tier    = "data"
  }
}

module "rabbitmq" {
  source = "../../modules/service-ec2"

  name_prefix  = local.name_prefix
  environment  = local.environment
  service_name = "rabbitmq"

  vpc_id              = data.aws_ssm_parameter.vpc_id.value
  subnet_id           = data.aws_subnet.data_a.id
  ami_id              = var.data_service_ami_id
  instance_type       = "t3.small"
  root_volume_size_gb = 20

  ingress_from_security_group_id = module.kubeadm_public_alb_workers.workers_security_group_id
  ingress_ports                  = [5672]

  ssh_key_name = var.ssh_key_name
  user_data    = local.data_service_user_data.rabbitmq

  s3_read_buckets     = ["scuad-prod-config"]
  enable_ecr_readonly = true

  tags = {
    Project = var.project
    Tier    = "data"
  }
}

module "weaviate" {
  source = "../../modules/service-ec2"

  name_prefix  = local.name_prefix
  environment  = local.environment
  service_name = "weaviate"

  vpc_id              = data.aws_ssm_parameter.vpc_id.value
  subnet_id           = data.aws_subnet.data_a.id
  ami_id              = var.data_service_ami_id
  instance_type       = "t3.small"
  root_volume_size_gb = 20

  ingress_from_security_group_id = module.kubeadm_public_alb_workers.workers_security_group_id
  ingress_ports                  = [8080, 50051]

  ssh_key_name = var.ssh_key_name
  user_data    = local.data_service_user_data.weaviate

  s3_read_buckets     = ["scuad-prod-config"]
  enable_ecr_readonly = true

  tags = {
    Project = var.project
    Tier    = "data"
  }
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

