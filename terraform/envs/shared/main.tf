terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28.0"
    }
  }
  required_version = ">= 1.14.3"
}

provider "aws" {
  region = var.region
}

locals {
  name_prefix = var.project_name
}

# Shared/global resources that should exist only once per AWS account/region.
module "ecr" {
  source = "../../modules/ecr"

  name                = var.ecr_repository_name
  lifecycle_keep_last = var.ecr_lifecycle_keep_last

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}
