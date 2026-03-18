variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (dev|staging|prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC id"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet ids where ALB will be placed"
  type        = list(string)
}

variable "worker_subnet_ids" {
  description = "Subnets for worker nodes (typically private app subnets)"
  type        = list(string)
}

variable "alb_certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener"
  type        = string
}

variable "nodeport_http" {
  description = "NodePort (HTTP) exposed on worker nodes (e.g., ingress-nginx NodePort)"
  type        = number
  default     = 30080
}

variable "health_check_path" {
  description = "ALB target group health check path"
  type        = string
  default     = "/"
}

variable "worker_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "worker_root_volume_size_gb" {
  description = "Root EBS volume size (GB) for worker nodes"
  type        = number
  default     = 30
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
  description = "cloud-init/user-data for worker nodes (kubeadm join etc.). If you set kubeadm join params below, this can be left null to use the built-in template."
  type        = string
  default     = null
}

variable "control_plane_endpoint" {
  description = "Kubeadm control-plane endpoint, e.g. internal NLB DNS name (without scheme). If null, built-in join template will fail unless worker_user_data is provided."
  type        = string
  default     = null
}

variable "kubeadm_join_token_ssm_param_name" {
  description = "SSM Parameter Store name containing kubeadm join token (String or SecureString)."
  type        = string
  default     = null
}

variable "kubeadm_ca_hash_ssm_param_name" {
  description = "SSM Parameter Store name containing discovery-token-ca-cert-hash (sha256:...)."
  type        = string
  default     = null
}

variable "http_proxy" {
  description = "Optional HTTP proxy for worker bootstrap"
  type        = string
  default     = null
}

variable "https_proxy" {
  description = "Optional HTTPS proxy for worker bootstrap"
  type        = string
  default     = null
}

variable "no_proxy" {
  description = "Optional NO_PROXY for worker bootstrap"
  type        = string
  default     = "127.0.0.1,localhost,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,169.254.169.254,.cluster.local"
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

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = "Kubernetes cluster name (used for cluster-autoscaler ASG auto-discovery tags)"
  type        = string
  default     = null
}

variable "enable_cluster_autoscaler" {
  description = "If true, tag the ASG for cluster-autoscaler auto-discovery and attach required IAM permissions to the worker role"
  type        = bool
  default     = false
}
