# VPC Peering: dev → staging / prod (for monitoring)
# dev 퍼블릭 서브넷의 모니터링 인스턴스가 staging/prod 프라이빗 인스턴스를 스크레이핑하기 위한 피어링

data "aws_vpc" "staging" {
  tags = {
    Name = "scuad-staging-vpc"
  }
}

data "aws_vpc" "prod" {
  tags = {
    Name = "scuad-prod-vpc"
  }
}

resource "aws_vpc_peering_connection" "dev_to_staging" {
  vpc_id      = module.network.vpc_id
  peer_vpc_id = data.aws_vpc.staging.id
  auto_accept = true

  tags = {
    Name        = "${local.name_prefix}-peer-to-staging"
    Environment = local.environment
  }
}

resource "aws_vpc_peering_connection" "dev_to_prod" {
  vpc_id      = module.network.vpc_id
  peer_vpc_id = data.aws_vpc.prod.id
  auto_accept = true

  tags = {
    Name        = "${local.name_prefix}-peer-to-prod"
    Environment = local.environment
  }
}

# dev 퍼블릭 라우트 테이블에서 staging/prod CIDR로 라우팅
data "aws_route_table" "dev_public" {
  filter {
    name   = "vpc-id"
    values = [module.network.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["${local.name_prefix}-public-rt"]
  }
}

resource "aws_route" "dev_public_to_staging" {
  route_table_id            = data.aws_route_table.dev_public.id
  destination_cidr_block    = data.aws_vpc.staging.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.dev_to_staging.id
}

resource "aws_route" "dev_public_to_prod" {
  route_table_id            = data.aws_route_table.dev_public.id
  destination_cidr_block    = data.aws_vpc.prod.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.dev_to_prod.id
}

output "dev_to_staging_peering_id" {
  value       = aws_vpc_peering_connection.dev_to_staging.id
  description = "Peering connection ID: dev → staging"
}

output "dev_to_prod_peering_id" {
  value       = aws_vpc_peering_connection.dev_to_prod.id
  description = "Peering connection ID: dev → prod"
}
