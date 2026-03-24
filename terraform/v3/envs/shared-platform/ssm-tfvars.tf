locals {
  managedby = "terraform"
}

resource "aws_ssm_parameter" "tfvars_v3_shared_network" {
  name        = "/tfvars/v3/shared-network"
  description = "Terraform tfvars for v3 shared-network"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE_OR_MAKEFILE__"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Project   = var.project
    ManagedBy = local.managedby
  }
}

resource "aws_ssm_parameter" "tfvars_v3_shared_platform" {
  name        = "/tfvars/v3/shared-platform"
  description = "Terraform tfvars for v3 shared-platform"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE_OR_MAKEFILE__"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Project   = var.project
    ManagedBy = local.managedby
  }
}

resource "aws_ssm_parameter" "tfvars_v3_dev" {
  name        = "/tfvars/v3/dev"
  description = "Terraform tfvars for v3 dev"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE_OR_MAKEFILE__"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Project   = var.project
    ManagedBy = local.managedby
  }
}

resource "aws_ssm_parameter" "tfvars_v3_staging" {
  name        = "/tfvars/v3/staging"
  description = "Terraform tfvars for v3 staging"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE_OR_MAKEFILE__"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Project   = var.project
    ManagedBy = local.managedby
  }
}

resource "aws_ssm_parameter" "tfvars_v3_prod" {
  name        = "/tfvars/v3/prod"
  description = "Terraform tfvars for v3 prod"
  type        = "SecureString"
  value       = "__SET_IN_CONSOLE_OR_MAKEFILE__"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Project   = var.project
    ManagedBy = local.managedby
  }
}
