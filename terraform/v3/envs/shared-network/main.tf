module "vpc" {
  source = "../../modules/vpc"

  name       = var.vpc_name
  cidr_block = var.vpc_cidr

  subnets = var.subnets

  tags = {
    Project = var.project
  }
}
