# Shared platform stack (ECR/S3/IAM/KMS/CloudWatch/VPC Endpoints, etc.)
# We'll add modules/resources here as we decide what should be shared.

locals {
  tags = {
    Project   = var.project
    ManagedBy = "Terraform"
  }
}
