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

  # Support both the old single-name var and the new list var.
  ecr_names = toset(
    distinct(
      compact(
        concat(
          var.ecr_repository_names,
          var.ecr_repository_name == null ? [] : [var.ecr_repository_name]
        )
      )
    )
  )
}

# Shared/global resources that should exist only once per AWS account/region.
module "ecr" {
  source   = "../../modules/ecr"
  for_each = local.ecr_names

  name                = each.value
  lifecycle_keep_last = var.ecr_lifecycle_keep_last

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
    Name      = each.value
  }
}

# Backward-compat: if exactly one repo is configured, expose its URL.
output "ecr_repository_url" {
  description = "(Legacy) URL of the single ECR repository when exactly one is configured; otherwise null."
  value       = length(local.ecr_names) == 1 ? module.ecr[tolist(local.ecr_names)[0]].repository_url : null
}

output "ecr_repository_urls" {
  description = "Map of ECR repository name -> repository URL"
  value       = { for name, m in module.ecr : name => m.repository_url }
}
