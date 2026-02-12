variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project_name" {
  type    = string
  default = "scuad"
}

variable "ecr_repository_name" {
  type    = string
  default = "scuad-registry"
}

variable "ecr_lifecycle_keep_last" {
  type    = number
  default = 50
}
