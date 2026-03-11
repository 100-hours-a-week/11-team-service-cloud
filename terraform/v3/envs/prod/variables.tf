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
