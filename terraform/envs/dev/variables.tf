variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project_name" {
  type    = string
  default = "scuad"
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["ap-northeast-2a", "ap-northeast-2b"]
}

variable "deployment_buckets" {
  type    = list(string)
  default = []
}

# ---- ALB HTTPS ----
variable "alb_certificate_arn" {
  description = "ACM certificate ARN for the public (internet-facing) ALB HTTPS listener. If null, HTTPS listener is not created."
  type        = string
  default     = null
}

# ---- Egress proxy (public subnet) ----
variable "enable_egress_proxy" {
  description = "Whether to create a public-subnet EC2 forward proxy for private instances' outbound internet access."
  type        = bool
  default     = false
}

variable "egress_proxy_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "egress_proxy_port" {
  description = "Proxy listen port (Squid default 3128)."
  type        = number
  default     = 3128
}

variable "egress_proxy_allow_all" {
  description = "If true, allow proxying to any destination (still restricted to requests originating from within the VPC CIDR)."
  type        = bool
  default     = false
}

variable "egress_proxy_allowed_domains" {
  description = "List of destination domains allowed through the proxy (Squid dstdomain) when egress_proxy_allow_all=false. Example: ['.kakao.com', '.kakao.co.kr']"
  type        = list(string)
  default     = []
}

variable "allowed_ssh_cidrs" {
  type    = list(string)
  default = []
}

variable "ssm_human_role_names" {
  type    = list(string)
  default = []
}

# ---- AMI ----
variable "ami_id" {
  description = "Custom AMI id to use for all instances. If null, use Ubuntu 24.04 SSM AMI."
  type        = string
  default     = null
}

# ---- ASG sizing ----
variable "web_instance_type" {
  type    = string
  default = "t3.small"
}

variable "web_asg_min" {
  type    = number
  default = 2
}

variable "web_asg_desired" {
  type    = number
  default = 2
}

variable "web_asg_max" {
  type    = number
  default = 6
}

variable "app_instance_type" {
  type    = string
  default = "t3.small"
}

variable "app_spring_asg_min" {
  type    = number
  default = 2
}

variable "app_spring_asg_desired" {
  type    = number
  default = 2
}

variable "app_spring_asg_max" {
  type    = number
  default = 6
}

variable "ai_instance_type" {
  type    = string
  default = "t3.small"
}

variable "ai_asg_min" {
  type    = number
  default = 2
}

variable "ai_asg_desired" {
  type    = number
  default = 2
}

variable "ai_asg_max" {
  type    = number
  default = 6
}

# ---- RDS ----
variable "db_engine_version" {
  type    = string
  default = "8.0.45"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.small"
}

variable "db_allocated_storage_gb" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = null
}

variable "db_username" {
  type    = string
  default = "scuad"
}

variable "db_password" {
  type      = string
  sensitive = true
}
