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
