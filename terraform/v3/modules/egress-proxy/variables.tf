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
  description = "Public subnet id where the proxy instance will be placed"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "proxy_port" {
  description = "Squid proxy port"
  type        = number
  default     = 3128
}

variable "allow_all" {
  description = "If true, allow proxy access to all destinations; otherwise restrict to allowed_domains"
  type        = bool
  default     = true
}

variable "allowed_domains" {
  description = "Allowed destination domains (used when allow_all=false)"
  type        = list(string)
  default     = []
}

variable "ami_id" {
  description = "AMI id override (optional). If null, Ubuntu 24.04 AMI from SSM is used."
  type        = string
  default     = null
}

variable "ssh_key_name" {
  description = "EC2 key pair name for SSH (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
