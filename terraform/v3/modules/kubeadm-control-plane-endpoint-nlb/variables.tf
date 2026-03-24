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

variable "subnet_ids" {
  description = "Subnet ids where the NLB will be placed (public subnets for internet-facing, private subnets for internal)."
  type        = list(string)
}

variable "internal" {
  description = "If true, create an internal NLB (recommended for SSM-only access)."
  type        = bool
  default     = false
}

variable "target_instance_ids" {
  description = "Control plane instance ids to register in the target group"
  type        = list(string)
}

variable "listener_port" {
  description = "NLB listener port (kube-apiserver)"
  type        = number
  default     = 6443
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
