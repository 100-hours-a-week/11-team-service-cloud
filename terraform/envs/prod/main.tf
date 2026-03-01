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
  environment = "prod"
  name_prefix = "${var.project_name}-${local.environment}"
}

module "iam" {
  source = "../../modules/iam"

  name_prefix          = local.name_prefix
  deployment_buckets   = var.deployment_buckets
  ssm_parameter_prefix = "/${var.project_name}/${local.environment}/"
}

module "network" {
  source = "../../modules/network"

  name_prefix       = local.name_prefix
  environment       = local.environment
  vpc_cidr          = var.vpc_cidr
  azs               = var.azs
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

module "rds" {
  source = "../../modules/rds"

  name_prefix          = local.name_prefix
  environment          = local.environment
  db_subnet_ids        = module.network.data_private_subnet_ids
  db_security_group_id = module.network.rds_security_group_id

  engine               = "mysql"
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  allocated_storage_gb = var.db_allocated_storage_gb

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  multi_az                = true
  backup_retention_period = 14
  deletion_protection     = true
  skip_final_snapshot     = false
}

# S3 bucket for staging config/artifacts (docker-compose, etc.)
# NOTE: S3 bucket name 규칙상 underscore(_)는 사용할 수 없어서 하이픈(-)을 써야 함.
module "scuad_prod_config" {
  source = "../../modules/s3"

  bucket_name = var.s3_config_bucket_name

  # Defaults (documented for clarity)
  enable_versioning   = true
  force_destroy       = false
  sse_algorithm       = "AES256"
  block_public_access = true
}

# S3 bucket for staging app data (uploads, etc.)
module "scuad_prod" {
  source = "../../modules/s3"

  bucket_name = var.s3_app_bucket_name

  enable_versioning   = true
  force_destroy       = false
  sse_algorithm       = "AES256"
  block_public_access = true
}

# SSM Parameter for backend (.env)
# NOTE: We intentionally ignore value changes so you can update it safely in the AWS Console
# without Terraform overwriting it on the next apply.
resource "aws_ssm_parameter" "staging_be_dot_env" {
  name        = "/${var.project_name}/${local.environment}/be/DOT_ENV"
  description = "scuad prod backend .env"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE__"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Environment = local.environment
    Project     = var.project_name
  }
}

resource "aws_ssm_parameter" "staging_fe_dot_env" {
  name        = "/${var.project_name}/${local.environment}/fe/DOT_ENV"
  description = "scuad prod frontend .env"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE__"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Environment = local.environment
    Project     = var.project_name
  }
}

resource "aws_ssm_parameter" "staging_ai_dot_env" {
  name        = "/${var.project_name}/${local.environment}/ai/DOT_ENV"
  description = "scuad prod ai .env"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE__"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Environment = local.environment
    Project     = var.project_name
  }
}

data "aws_ssm_parameter" "ubuntu_2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.ubuntu_2404_ami.value
}
output "rds_endpoint" { value = module.rds.endpoint }
