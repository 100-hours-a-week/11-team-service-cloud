# VPC Peering: prod ← dev (monitoring 역방향 라우트)
# dev 퍼블릭의 모니터링 인스턴스가 prod 프라이빗 인스턴스에 접근할 수 있도록 라우팅

variable "dev_vpc_cidr" {
  description = "CIDR block of the dev VPC (for monitoring peering route)"
  type        = string
  default     = "10.1.0.0/16"
}

# dev 환경에서 생성된 피어링 커넥션을 태그로 조회
data "aws_vpc_peering_connection" "from_dev" {
  tags = {
    Name = "scuad-dev-peer-to-prod"
  }
}

# prod 프라이빗 라우트 테이블에서 dev CIDR로 라우팅
data "aws_route_table" "prod_private" {
  filter {
    name   = "vpc-id"
    values = [module.network.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["${local.name_prefix}-private-rt"]
  }
}

resource "aws_route" "prod_private_to_dev" {
  route_table_id            = data.aws_route_table.prod_private.id
  destination_cidr_block    = var.dev_vpc_cidr
  vpc_peering_connection_id = data.aws_vpc_peering_connection.from_dev.id
}

# prod 인스턴스 SG에 dev 모니터링 → node_exporter(:9100) 스크레이핑 허용
resource "aws_security_group_rule" "allow_node_exporter_from_dev_web" {
  type              = "ingress"
  security_group_id = module.network.web_security_group_id
  from_port         = 9100
  to_port           = 9100
  protocol          = "tcp"
  cidr_blocks       = [var.dev_vpc_cidr]
  description       = "Allow Prometheus node_exporter scrape from dev monitoring"
}

resource "aws_security_group_rule" "allow_node_exporter_from_dev_spring" {
  type              = "ingress"
  security_group_id = module.network.app_spring_security_group_id
  from_port         = 9100
  to_port           = 9100
  protocol          = "tcp"
  cidr_blocks       = [var.dev_vpc_cidr]
  description       = "Allow Prometheus node_exporter scrape from dev monitoring"
}

resource "aws_security_group_rule" "allow_node_exporter_from_dev_ai" {
  type              = "ingress"
  security_group_id = module.network.app_ai_security_group_id
  from_port         = 9100
  to_port           = 9100
  protocol          = "tcp"
  cidr_blocks       = [var.dev_vpc_cidr]
  description       = "Allow Prometheus node_exporter scrape from dev monitoring"
}
