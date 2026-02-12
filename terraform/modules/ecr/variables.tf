variable "name" {
  description = "ECR repository name (single repo shared across envs)"
  type        = string
}

variable "image_tag_mutability" {
  description = "MUTABLE or IMMUTABLE"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable image scan on push"
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Allow terraform destroy to delete repo even if images exist (use with caution)"
  type        = bool
  default     = false
}

variable "lifecycle_keep_last" {
  description = "How many tagged images to keep (approx). Set null to disable lifecycle policy."
  type        = number
  default     = 50
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
