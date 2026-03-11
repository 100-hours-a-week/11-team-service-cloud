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

variable "ssh_key_name" {
  description = "EC2 key pair name for SSH (optional)"
  type        = string
  default     = null
}

variable "worker_user_data" {
  description = "cloud-init/user-data for worker nodes (kubeadm join etc.)"
  type        = string
  default     = "#!/bin/bash\nset -euxo pipefail\n# TODO: install container runtime + kubelet/kubeadm and run kubeadm join\n"
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
