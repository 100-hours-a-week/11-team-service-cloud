variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "azs" {
  description = "Availability zones (optional, mainly for validation/documentation)"
  type        = list(string)
  default     = []
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

variable "enable_ssm_vpc_endpoints" {
  description = "If true, create VPC interface endpoints for SSM (ssm/ec2messages/ssmmessages) so private subnets can use Session Manager without NAT."
  type        = bool
  default     = true
}

variable "enable_ecr_vpc_endpoints" {
  description = "If true, create VPC endpoints for ECR (ecr.api/ecr.dkr) and S3 so private subnets can pull images without NAT/proxy."
  type        = bool
  default     = true
}
