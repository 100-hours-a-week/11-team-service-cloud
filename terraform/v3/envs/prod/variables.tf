variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "scuad"
}

variable "vpc_id_ssm_param_name" {
  description = "SSM parameter name where shared VPC id is stored"
  type        = string
  default     = "/scuad/v3/network/vpc_id"
}

variable "alb_certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS listener"
  type        = string
}

variable "db_password" {
  description = "RDS MySQL master password (prod)"
  type        = string
  sensitive   = true
}

variable "data_service_ami_id" {
  description = "AMI id for data service EC2 instances (redis/rabbitmq/weaviate)"
  type        = string
}

variable "nodeport_http" {
  description = "NodePort used by ingress-nginx (HTTP)"
  type        = number
  default     = 30080
}

variable "health_check_path" {
  description = "ALB target group health check path"
  type        = string
  default     = "/"
}

variable "workers_min" {
  type    = number
  default = 3
}

variable "workers_desired" {
  type    = number
  default = 3
}

variable "workers_max" {
  type    = number
  default = 6
}

variable "worker_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "worker_ami_id" {
  description = "Worker node AMI override (optional). If null, Ubuntu 24.04 AMI from SSM is used."
  type        = string
  default     = null
}

# -------------------------
# Control plane (kubeadm)
# -------------------------
variable "control_plane_ami_id" {
  description = "AMI id for the control plane instances"
  type        = string
}

variable "control_plane_instance_type" {
  description = "EC2 instance type for control plane"
  type        = string
  default     = "t3.medium"
}

variable "control_plane_replicas" {
  description = "Number of control plane instances"
  type        = number
  default     = 3
}

variable "control_plane_user_data" {
  description = "cloud-init/user-data for control plane (kubeadm init/join etc.)"
  type        = string
  default     = "#!/bin/bash\nset -euxo pipefail\n# TODO: install container runtime + kubelet/kubeadm and run kubeadm init/join\n"
}

variable "control_plane_allowed_api_cidrs" {
  description = "CIDRs allowed to reach kube-apiserver (6443). For SSM-only access, restrict to VPC CIDR(s)."
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "ssh_key_name" {
  description = "EC2 key pair name for SSH (optional)"
  type        = string
  default     = null
}

variable "worker_user_data" {
  description = "Optional override user-data for worker nodes. If null, the kubeadm auto-join template is used."
  type        = string
  default     = null
}

variable "kubeadm_join_token_ssm_param_name" {
  description = "SSM parameter name containing kubeadm join token"
  type        = string
}

variable "kubeadm_ca_hash_ssm_param_name" {
  description = "SSM parameter name containing discovery-token-ca-cert-hash"
  type        = string
}

variable "kubeadm_control_plane_endpoint_ssm_param_name" {
  description = "SSM parameter name containing kubeadm control plane endpoint (DNS:6443)"
  type        = string
  default     = "/scuad/v3/prod/kubeadm/control_plane_endpoint"
}

variable "kubeadm_control_plane_endpoint" {
  description = "Kubeadm control plane endpoint override (DNS/IP without scheme). If null, internal NLB DNS is used."
  type        = string
  default     = null
}

variable "egress_proxy_instance_type" {
  description = "EC2 instance type for egress proxy"
  type        = string
  default     = "t3.micro"
}

variable "egress_proxy_port" {
  description = "Forward proxy port"
  type        = number
  default     = 3128
}

variable "egress_proxy_allow_all" {
  description = "If true, allow proxy to all destinations"
  type        = bool
  default     = true
}

variable "egress_proxy_allowed_domains" {
  description = "Allowed destination domains (used when egress_proxy_allow_all=false)"
  type        = list(string)
  default     = []
}
