variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (dev|staging|prod)"
  type        = string
}

variable "service_name" {
  description = "Service name (e.g., redis|rabbitmq|weaviate)"
  type        = string
}

variable "vpc_id" {
  description = "VPC id"
  type        = string
}

variable "subnet_id" {
  description = "Subnet id to place the instance"
  type        = string
}

variable "ami_id" {
  description = "AMI id"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size (GB)"
  type        = number
  default     = 20
}

variable "ingress_from_security_group_id" {
  description = "Only allow inbound traffic from this security group (e.g., k8s workers SG)"
  type        = string
}

variable "ingress_ports" {
  description = "TCP ports to allow inbound from ingress_from_security_group_id"
  type        = list(number)
}

variable "ssh_key_name" {
  description = "Optional EC2 key pair name"
  type        = string
  default     = null
}

variable "enable_ecr_readonly" {
  description = "Attach AmazonEC2ContainerRegistryReadOnly to the instance role"
  type        = bool
  default     = true
}

variable "s3_read_buckets" {
  description = "S3 buckets (names) to allow read access for fetching docker-compose/assets"
  type        = list(string)
  default     = []
}

variable "user_data" {
  description = "cloud-init/user-data"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
