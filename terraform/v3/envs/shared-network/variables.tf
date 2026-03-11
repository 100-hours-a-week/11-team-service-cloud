variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "azs" {
  description = "Availability zones (optional, mainly for validation/documentation)"
  type        = list(string)
  default     = []
}

variable "subnets" {
  description = "Subnet definitions"
  type = list(object({
    name        = string
    cidr        = string
    az          = string
    public      = bool
    environment = string
    tier        = string
  }))
}
