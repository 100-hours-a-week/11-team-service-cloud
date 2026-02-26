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

# S3 bucket for shared config/artifacts
# NOTE: S3 bucket name 규칙상 underscore(_)는 사용할 수 없어서 하이픈(-)을 써야 함.
module "scuad_dev_config" {
  source = "../../modules/s3"

  bucket_name       = var.s3_config_bucket_name
  enable_versioning = var.s3_config_enable_versioning
  force_destroy     = var.s3_config_force_destroy

  sse_algorithm = var.s3_config_sse_algorithm
  kms_key_id    = var.s3_config_kms_key_id

  # Network stack과 결합할 때만 켜는 걸 추천 (shared는 보통 network를 안 만드니까 기본 false)
  restrict_to_vpce = var.s3_config_restrict_to_vpce
  vpce_id          = var.s3_config_vpce_id
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

output "s3_config_bucket_name" {
  description = "S3 bucket name for shared config/artifacts"
  value       = module.scuad_dev_config.bucket_name
}

output "s3_config_bucket_arn" {
  description = "S3 bucket ARN for shared config/artifacts"
  value       = module.scuad_dev_config.bucket_arn
}
