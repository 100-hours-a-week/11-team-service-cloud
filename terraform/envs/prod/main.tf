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

output "rds_endpoint" { value = module.rds.endpoint }
