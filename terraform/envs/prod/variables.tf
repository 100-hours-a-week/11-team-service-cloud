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
  default = "10.3.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "deployment_buckets" {
  type    = list(string)
  default = []
}

variable "allowed_ssh_cidrs" {
  type    = list(string)
  default = []
}

variable "ssm_human_role_names" {
  type    = list(string)
  default = []
}

variable "web_instance_type" {
  type    = string
  default = "t3.medium"
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
  default = 10
}

variable "app_instance_type" {
  type    = string
  default = "t3.medium"
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
  default = 10
}

variable "ai_instance_type" {
  type    = string
  default = "t3.medium"
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
  default = 10
}

variable "db_engine_version" {
  type    = string
  default = "8.0.45"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "db_allocated_storage_gb" {
  type    = number
  default = 50
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
