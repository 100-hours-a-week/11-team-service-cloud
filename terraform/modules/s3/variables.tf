variable "bucket_name" {
  description = "S3 bucket name (must be globally unique)."
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "Whether to allow Terraform to destroy the bucket even if it contains objects."
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning."
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "Server-side encryption algorithm. Use \"AES256\" or \"aws:kms\"."
  type        = string
  default     = "AES256"
  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "sse_algorithm must be one of: AES256, aws:kms."
  }
}

variable "kms_key_id" {
  description = "KMS key id/arn when sse_algorithm=\"aws:kms\"."
  type        = string
  default     = null
}

variable "block_public_access" {
  description = "Apply S3 public access block settings (recommended)."
  type        = bool
  default     = true
}

variable "restrict_to_vpce" {
  description = "If true, attach a bucket policy to allow access only when requests come via the given VPC Endpoint (aws:sourceVpce)."
  type        = bool
  default     = false
}

variable "vpce_id" {
  description = "VPC Endpoint id (vpce-...) used when restrict_to_vpce=true."
  type        = string
  default     = null
}
