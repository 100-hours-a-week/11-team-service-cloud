variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project" {
  type = string
}

variable "name_prefix" {
  description = "Prefix for shared platform resources (ECR, S3, etc.)"
  type        = string
}
