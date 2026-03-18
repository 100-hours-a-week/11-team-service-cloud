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

variable "subnet_id" {
  description = "Subnet id where the builder instance will be placed"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ssh_key_name" {
  description = "EC2 key pair name for SSH (optional)"
  type        = string
  default     = null
}

variable "allowed_ssh_cidrs" {
  description = "Optional SSH allowlist"
  type        = list(string)
  default     = []
}

variable "enable_proxy" {
  description = "Whether to configure HTTP(S) proxy for package downloads"
  type        = bool
  default     = true
}

variable "proxy_private_ip" {
  description = "Egress proxy private IP (HTTP/HTTPS proxy). Required when enable_proxy=true"
  type        = string
  default     = null
}

variable "proxy_port" {
  description = "Egress proxy port"
  type        = number
  default     = 3128
}

variable "k8s_minor_version" {
  description = "Kubernetes stable channel (e.g. v1.29, v1.30). Used in pkgs.k8s.io URL as /stable:/<value>/deb"
  type        = string
  default     = "v1.29"
}

variable "helm_version" {
  description = "Helm version tag"
  type        = string
  default     = "v3.15.4"
}

variable "pause_image" {
  description = "ECR mirrored pause image (for containerd sandbox_image)"
  type        = string
}

variable "no_proxy" {
  description = "NO_PROXY value"
  type        = string
  default     = "127.0.0.1,localhost,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,10.96.0.0/12,169.254.169.254,.cluster.local,.amazonaws.com,.ecr.ap-northeast-2.amazonaws.com,.dkr.ecr.ap-northeast-2.amazonaws.com,.s3.ap-northeast-2.amazonaws.com"
}

variable "ami_id" {
  description = "Base AMI override (optional). If null, Ubuntu 24.04 AMI from SSM is used."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
