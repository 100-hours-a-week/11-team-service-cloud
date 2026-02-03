# Modules

module "iam" {
  source = "./modules/iam"

  deployment_buckets = var.deployment_buckets
}

module "network" {
  source = "./modules/network"

  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

module "compute" {
  source = "./modules/compute"

  vpc_id                    = module.network.vpc_id
  subnet_id                 = module.network.public_subnet_a_id
  security_group_id         = module.network.security_group_id
  iam_instance_profile_name = module.iam.iam_instance_profile_name

  key_name = var.ssh_key_name
}

# EIP 할당 (root level에서 관리하여 순환참조 방지)

resource "aws_eip_association" "bigbang" {
  allocation_id = module.network.eip_id
  instance_id   = module.compute.instance_id
}
