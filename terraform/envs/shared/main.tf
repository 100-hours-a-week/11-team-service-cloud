terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28.0"
    }
  }
  required_version = ">= 1.14.3"

  backend "s3" {
    bucket         = "scuad-tfstate-ap-northeast-2"
    key            = "envs/shared/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "scuad-tfstate-lock"
    encrypt        = true
  }
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

# -------------------------
# Terraform tfvars (per env) - SSM SecureString
# 실제 값은 AWS Console 또는 CLI로 설정.
# Terraform은 파라미터 존재만 관리하고 value는 ignore.
# -------------------------
resource "aws_ssm_parameter" "tfvars_v1" {
  name        = "/tfvars/v1"
  description = "Terraform tfvars for v1"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE__"

  lifecycle { ignore_changes = [value] }

  tags = { Project = var.project_name, ManagedBy = "terraform" }
}

resource "aws_ssm_parameter" "tfvars_shared" {
  name        = "/tfvars/shared"
  description = "Terraform tfvars for shared"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE__"

  lifecycle { ignore_changes = [value] }

  tags = { Project = var.project_name, ManagedBy = "terraform" }
}

resource "aws_ssm_parameter" "tfvars_dev" {
  name        = "/tfvars/dev"
  description = "Terraform tfvars for dev"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE__"

  lifecycle { ignore_changes = [value] }

  tags = { Project = var.project_name, ManagedBy = "terraform" }
}

resource "aws_ssm_parameter" "tfvars_staging" {
  name        = "/tfvars/staging"
  description = "Terraform tfvars for staging"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE__"

  lifecycle { ignore_changes = [value] }

  tags = { Project = var.project_name, ManagedBy = "terraform" }
}

resource "aws_ssm_parameter" "tfvars_prod" {
  name        = "/tfvars/prod"
  description = "Terraform tfvars for prod"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE__"

  lifecycle { ignore_changes = [value] }

  tags = { Project = var.project_name, ManagedBy = "terraform" }
}

# -------------------------
# Terraform Backend Resources
# -------------------------
module "tfstate_bucket" {
  source = "../../modules/s3"

  bucket_name         = var.tfstate_bucket_name
  enable_versioning   = true
  force_destroy       = false
  sse_algorithm       = "AES256"
  block_public_access = true
}

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = var.tfstate_dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
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

output "s3_config_bucket_name" {
  description = "S3 bucket name for shared config/artifacts"
  value       = module.scuad_dev_config.bucket_name
}

output "s3_config_bucket_arn" {
  description = "S3 bucket ARN for shared config/artifacts"
  value       = module.scuad_dev_config.bucket_arn
}

output "tfstate_bucket_name" {
  description = "S3 bucket name for Terraform remote state"
  value       = module.tfstate_bucket.bucket_name
}

output "tfstate_dynamodb_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  value       = aws_dynamodb_table.tfstate_lock.name
}
