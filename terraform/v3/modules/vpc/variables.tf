variable "name" {
  description = "VPC name"
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR"
  type        = string
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

variable "tags" {
  description = "Tags applied to resources"
  type        = map(string)
  default     = {}
}

variable "enable_ssm_vpc_endpoints" {
  description = "If true, create VPC interface endpoints for SSM so private subnets can use Session Manager without NAT."
  type        = bool
  default     = false
}

variable "enable_ecr_vpc_endpoints" {
  description = "If true, create VPC endpoints for ECR (ecr.api, ecr.dkr) and S3 so private subnets can pull container images without NAT/proxy."
  type        = bool
  default     = false
}

variable "ssm_endpoint_subnet_ids" {
  description = "Subnet IDs for the SSM interface endpoints. If null, all private subnets created by this module are used."
  type        = list(string)
  default     = null
}
