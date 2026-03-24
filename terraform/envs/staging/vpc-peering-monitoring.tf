# VPC Peering: staging ← dev (monitoring 역방향 라우트)
# dev 퍼블릭의 모니터링 인스턴스가 staging 프라이빗 인스턴스에 접근할 수 있도록 라우팅

variable "dev_vpc_cidr" {
  description = "CIDR block of the dev VPC (for monitoring peering route)"
  type        = string
  default     = "10.1.0.0/16"
}

# dev 환경에서 생성된 피어링 커넥션을 태그로 조회
data "aws_vpc_peering_connection" "from_dev" {
  tags = {
    Name = "scuad-dev-peer-to-staging"
  }
}

# staging 프라이빗 라우트 테이블에서 dev CIDR로 라우팅
data "aws_route_table" "staging_private" {
  filter {
    name   = "vpc-id"
    values = [module.network.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["${local.name_prefix}-private-rt"]
  }
}

resource "aws_route" "staging_private_to_dev" {
  route_table_id            = data.aws_route_table.staging_private.id
  destination_cidr_block    = var.dev_vpc_cidr
  vpc_peering_connection_id = data.aws_vpc_peering_connection.from_dev.id
}

# staging public 서브넷(egress proxy)에서 dev로의 응답 라우팅
data "aws_route_table" "staging_public" {
  filter {
    name   = "vpc-id"
    values = [module.network.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["${local.name_prefix}-public-rt"]
  }
}

resource "aws_route" "staging_public_to_dev" {
  route_table_id            = data.aws_route_table.staging_public.id
  destination_cidr_block    = var.dev_vpc_cidr
  vpc_peering_connection_id = data.aws_vpc_peering_connection.from_dev.id
}
