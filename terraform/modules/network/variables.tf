variable "name_prefix" {
  description = "Resource name prefix (e.g., project-env)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev|staging|prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "azs" {
  description = "Two availability zones to use (e.g., [ap-northeast-2a, ap-northeast-2c])"
  type        = list(string)
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed for SSH (if you keep SSH open)"
  type        = list(string)
  default     = []
}

variable "create_eip" {
  description = "(Legacy) Create an EIP for single-instance bigbang"
  type        = bool
  default     = false
}

variable "node_exporter_cidr_blocks" {
  description = "CIDR blocks allowed to scrape node_exporter (:9100) on web/spring/ai instances"
  type        = list(string)
  default     = []
}

variable "cadvisor_allowed_cidrs" {
  description = "CIDR blocks allowed to scrape cadvisor (:9102) on web/spring/ai instances"
  type        = list(string)
  default     = []
}

variable "app_metrics_allowed_cidrs" {
  description = "CIDR blocks allowed to scrape application metrics (:9101) on spring instances"
  type        = list(string)
  default     = []
}
