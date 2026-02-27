variable "name_prefix" {
  description = "Resource name prefix (e.g., project-env)"
  type        = string
}

variable "deployment_buckets" {
  description = "List of S3 bucket names for deployment"
  type        = list(string)
  default     = []
}

variable "ssm_parameter_prefix" {
  description = "SSM Parameter Store path prefix the instances may read (e.g., /scuad/dev/)"
  type        = string
  default     = "/"
}
