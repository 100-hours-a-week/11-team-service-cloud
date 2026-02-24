# VPC Peering: legacy(V1) EC2(MySQL) VPC <-> dev(V2) VPC(RDS)

resource "aws_vpc_peering_connection" "v1_to_v2" {
  vpc_id      = var.v1_vpc_id
  peer_vpc_id = module.network.vpc_id
  peer_region = var.region

  tags = {
    Name        = "${local.name_prefix}-peer-v1-to-v2"
    Environment = local.environment
  }
}

resource "aws_vpc_peering_connection_accepter" "v2_accept" {
  vpc_peering_connection_id = aws_vpc_peering_connection.v1_to_v2.id
  auto_accept               = true

  tags = {
    Name        = "${local.name_prefix}-peer-v1-to-v2"
    Environment = local.environment
  }
}

# -------------------------
# Routes
# - V1 route tables: route to V2 CIDR via peering
# - V2(private rt): route to V1 CIDR via peering
# -------------------------

data "aws_route_tables" "v1" {
  vpc_id = var.v1_vpc_id
}

# Add route in every V1 route table (safe default; ensures the EC2 subnet's RT is covered)
resource "aws_route" "v1_to_v2" {
  for_each = toset(data.aws_route_tables.v1.ids)

  route_table_id            = each.value
  destination_cidr_block    = var.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.v1_to_v2.id

  depends_on = [aws_vpc_peering_connection_accepter.v2_accept]
}

# Find the dev(V2) private route table created by the network module
# (all private subnets: web/app/data are associated to this private RT)
data "aws_route_table" "v2_private" {
  filter {
    name   = "vpc-id"
    values = [module.network.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["${local.name_prefix}-private-rt"]
  }
}

resource "aws_route" "v2_to_v1" {
  route_table_id            = data.aws_route_table.v2_private.id
  destination_cidr_block    = var.v1_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.v1_to_v2.id

  depends_on = [aws_vpc_peering_connection_accepter.v2_accept]
}

# -------------------------
# Security Group: allow MySQL(3306) from V1 VPC CIDR to RDS SG
# -------------------------
resource "aws_security_group_rule" "rds_mysql_from_v1" {
  type              = "ingress"
  security_group_id = module.network.rds_security_group_id

  from_port   = 3306
  to_port     = 3306
  protocol    = "tcp"
  cidr_blocks = [var.v1_vpc_cidr]

  description = "Allow MySQL from legacy(V1) VPC for migration"
}