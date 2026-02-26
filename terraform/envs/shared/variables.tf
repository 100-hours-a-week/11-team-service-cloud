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

# ---- S3 (shared config/artifacts) ----
variable "s3_config_bucket_name" {
  description = "S3 bucket name for shared config/artifacts. Must be globally unique; underscore(_) is NOT allowed by S3 rules."
  type        = string
  default     = null
}

variable "s3_config_force_destroy" {
  description = "Allow Terraform to destroy the bucket even if it contains objects."
  type        = bool
  default     = false
}

variable "s3_config_enable_versioning" {
  type    = bool
  default = true
}

variable "s3_config_sse_algorithm" {
  description = "Server-side encryption algorithm. AES256 or aws:kms."
  type        = string
  default     = "AES256"
}

variable "s3_config_kms_key_id" {
  description = "KMS key id/arn when s3_config_sse_algorithm=aws:kms"
  type        = string
  default     = null
}

variable "s3_config_restrict_to_vpce" {
  description = "If true, attach a bucket policy to allow access only via the given VPC Endpoint id. Usually set in network-aware stacks."
  type        = bool
  default     = false
}

variable "s3_config_vpce_id" {
  description = "VPC Endpoint id (vpce-...) used when s3_config_restrict_to_vpce=true."
  type        = string
  default     = null
}
