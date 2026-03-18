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
  description = "Subnet id where the control plane instance will be placed"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "AMI id for control plane instance"
  type        = string
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

variable "allowed_api_cidrs" {
  description = "CIDRs allowed to reach kube-apiserver (6443). Should include worker/node CIDRs."
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "control_plane_user_data" {
  description = "cloud-init/user-data for control plane (install deps + kubeadm init etc.)"
  type        = string
  default     = "#!/bin/bash\nset -euxo pipefail\n# TODO: install container runtime + kubelet/kubeadm and run kubeadm init\n"
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
