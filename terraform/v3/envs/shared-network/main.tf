module "vpc" {
  source = "../../modules/vpc"

  name       = var.vpc_name
  cidr_block = var.vpc_cidr

  subnets = var.subnets

  enable_ssm_vpc_endpoints = var.enable_ssm_vpc_endpoints
  enable_ecr_vpc_endpoints = var.enable_ecr_vpc_endpoints

  tags = {
    Project                               = var.project
    "kubernetes.io/cluster/scuad-cluster" = "owned"
  }
}
