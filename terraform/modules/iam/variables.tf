variable "deployment_buckets" {
  description = "List of S3 bucket names for deployment"
  type        = list(string)
  default     = []
}
