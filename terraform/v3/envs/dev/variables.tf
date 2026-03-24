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
  description = "RDS MySQL master password (dev)"
  type        = string
  sensitive   = true
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
  default = 2
}

variable "workers_desired" {
  type    = number
  default = 2
}

variable "workers_max" {
  type    = number
  default = 3
}

variable "cluster_name" {
  description = "Kubernetes cluster name (used by cluster-autoscaler)"
  type        = string
  default     = "scuad-cluster"
}

variable "enable_cluster_autoscaler" {
  description = "Enable cluster-autoscaler integration (ASG tags + IAM on worker role)"
  type        = bool
  default     = false
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

variable "kubeadm_control_plane_endpoint" {
  description = "Kubeadm control plane endpoint (DNS/IP without scheme). Typically NLB DNS name."
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

# -------------------------
# Golden AMI builder
# -------------------------
variable "ami_builder_instance_type" {
  description = "EC2 instance type for golden AMI builder instances"
  type        = string
  default     = "t3.medium"
}

variable "ami_builder_allowed_ssh_cidrs" {
  description = "Optional SSH allowlist for AMI builder instances"
  type        = list(string)
  default     = []
}

variable "ami_builder_enable_proxy" {
  description = "Whether golden AMI builder instances should use the egress proxy"
  type        = bool
  default     = true
}

variable "k8s_minor_version" {
  description = "Kubernetes stable channel used by pkgs.k8s.io (e.g. v1.29, v1.30)"
  type        = string
  default     = "v1.29"
}

variable "helm_version" {
  description = "Helm version tag"
  type        = string
  default     = "v3.15.4"
}

variable "pause_image" {
  description = "ECR mirrored pause image"
  type        = string
}

# -------------------------
# Control plane (kubeadm)
# -------------------------
variable "control_plane_ami_id" {
  description = "AMI id for the control plane instance"
  type        = string
}

variable "control_plane_instance_type" {
  description = "EC2 instance type for the control plane instance"
  type        = string
  default     = "t3.medium"
}

variable "control_plane_replicas" {
  description = "Number of control plane instances (dev default: 1)"
  type        = number
  default     = 1
}

variable "control_plane_user_data" {
  description = "cloud-init/user-data for control plane (kubeadm init etc.)"
  type        = string
  default     = "#!/bin/bash\nset -euxo pipefail\n# TODO: install container runtime + kubelet/kubeadm and run kubeadm init\n"
}

variable "control_plane_allowed_api_cidrs" {
  description = "CIDRs allowed to reach kube-apiserver (6443). Should include worker subnet CIDRs."
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}
