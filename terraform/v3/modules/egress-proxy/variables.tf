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
  description = "(Deprecated) Public subnet id where the proxy instance will be placed. Prefer subnet_ids."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Public subnet ids where proxy instances will be placed (one per subnet). If null, subnet_id is used."
  type        = list(string)
  default     = null
}

variable "enable_nlb" {
  description = "If true, create an internal NLB endpoint in front of the proxy instances. If false, only instances are created."
  type        = bool
  default     = false
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
