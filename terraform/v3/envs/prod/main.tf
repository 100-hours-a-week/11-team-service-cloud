locals {
  environment = "prod"
  name_prefix = "${var.project}-${local.environment}"
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
