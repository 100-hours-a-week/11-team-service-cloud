variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project_name" {
  type    = string
  default = "scuad"
}

# Backward-compat (single repo). Prefer ecr_repository_names.
variable "ecr_repository_name" {
  type    = string
  default = null
}

# Create one ECR repository per name.
variable "ecr_repository_names" {
  type    = list(string)
  default = []
}

variable "ecr_lifecycle_keep_last" {
  type    = number
  default = 50
}
