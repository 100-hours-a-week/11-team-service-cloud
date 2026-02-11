variable "role_names" {
  description = "Existing IAM role names to grant SSM human access"
  type        = list(string)
}

variable "policy_name" {
  description = "Name for the policy"
  type        = string
  default     = "ssm-session-access"
}
