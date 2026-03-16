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
