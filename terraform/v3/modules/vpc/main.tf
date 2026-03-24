locals {
  base_tags = merge(var.tags, {
    Name = var.name
  })

  subnets_by_name = { for s in var.subnets : s.name => s }
  public_subnets  = { for k, s in local.subnets_by_name : k => s if s.public }
  private_subnets = { for k, s in local.subnets_by_name : k => s if !s.public }
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = local.base_tags
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_subnet" "this" {
  for_each = local.subnets_by_name

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.public

  tags = merge(local.base_tags, {
    Name        = each.value.name
    Environment = each.value.environment
    Tier        = each.value.tier
    Public      = tostring(each.value.public)
  })
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, {
    Name = "${var.name}-public-rt"
  })
}

resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public.id
}

# --------------------------------------
# VPC Interface Endpoints (SSM)
# --------------------------------------
# This enables SSM Session Manager for instances in private subnets without NAT.

data "aws_region" "current" {}

data "aws_vpc_endpoint_service" "ssm" {
  count   = var.enable_ssm_vpc_endpoints ? 1 : 0
  service = "ssm"
}

data "aws_vpc_endpoint_service" "ec2messages" {
  count   = var.enable_ssm_vpc_endpoints ? 1 : 0
  service = "ec2messages"
}

data "aws_vpc_endpoint_service" "ssmmessages" {
  count   = var.enable_ssm_vpc_endpoints ? 1 : 0
  service = "ssmmessages"
}

# --------------------------------------
# VPC Interface Endpoints (ECR)
# --------------------------------------
# This enables container image pulls from ECR in private subnets without NAT/proxy.

data "aws_vpc_endpoint_service" "ecr_api" {
  count   = var.enable_ecr_vpc_endpoints ? 1 : 0
  service = "ecr.api"
}

data "aws_vpc_endpoint_service" "ecr_dkr" {
  count   = var.enable_ecr_vpc_endpoints ? 1 : 0
  service = "ecr.dkr"
}

# NOTE: We intentionally do NOT use data.aws_vpc_endpoint_service for S3.
# Some accounts/regions can return multiple matches for "s3".
# The gateway endpoint service name is stable.
locals {
  s3_gateway_service_name = "com.amazonaws.${data.aws_region.current.id}.s3"
}

locals {
  # Interface endpoints allow at most one subnet per AZ. If multiple private subnets exist in the same AZ,
  # we must de-duplicate by availability zone.
  ssm_endpoint_subnet_ids_by_az = {
    for k, s in local.private_subnets : aws_subnet.this[k].availability_zone => aws_subnet.this[k].id...
  }

  default_ssm_endpoint_subnet_ids = [
    for az, ids in local.ssm_endpoint_subnet_ids_by_az : ids[0]
  ]

  ssm_endpoint_subnet_ids = var.ssm_endpoint_subnet_ids != null ? var.ssm_endpoint_subnet_ids : local.default_ssm_endpoint_subnet_ids
}

resource "aws_security_group" "vpce" {
  count       = (var.enable_ssm_vpc_endpoints || var.enable_ecr_vpc_endpoints) ? 1 : 0
  name        = "${var.name}-vpce-sg"
  description = "Security group for VPC interface endpoints (SSM)"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from within VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, {
    Name = "${var.name}-vpce-sg"
  })
}

resource "aws_vpc_endpoint" "ssm" {
  count               = var.enable_ssm_vpc_endpoints ? 1 : 0
  vpc_id              = aws_vpc.this.id
  service_name        = data.aws_vpc_endpoint_service.ssm[0].service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = local.ssm_endpoint_subnet_ids
  security_group_ids = [aws_security_group.vpce[0].id]

  tags = merge(local.base_tags, {
    Name = "${var.name}-vpce-ssm"
  })
}

resource "aws_vpc_endpoint" "ec2messages" {
  count               = var.enable_ssm_vpc_endpoints ? 1 : 0
  vpc_id              = aws_vpc.this.id
  service_name        = data.aws_vpc_endpoint_service.ec2messages[0].service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = local.ssm_endpoint_subnet_ids
  security_group_ids = [aws_security_group.vpce[0].id]

  tags = merge(local.base_tags, {
    Name = "${var.name}-vpce-ec2messages"
  })
}

resource "aws_vpc_endpoint" "ssmmessages" {
  count               = var.enable_ssm_vpc_endpoints ? 1 : 0
  vpc_id              = aws_vpc.this.id
  service_name        = data.aws_vpc_endpoint_service.ssmmessages[0].service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = local.ssm_endpoint_subnet_ids
  security_group_ids = [aws_security_group.vpce[0].id]

  tags = merge(local.base_tags, {
    Name = "${var.name}-vpce-ssmmessages"
  })
}

# --------------------------------------
# VPC Endpoints (ECR + S3)
# --------------------------------------

resource "aws_vpc_endpoint" "ecr_api" {
  count               = var.enable_ecr_vpc_endpoints ? 1 : 0
  vpc_id              = aws_vpc.this.id
  service_name        = data.aws_vpc_endpoint_service.ecr_api[0].service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  # Reuse the same subnet selection logic as SSM endpoints.
  subnet_ids         = local.ssm_endpoint_subnet_ids
  security_group_ids = [aws_security_group.vpce[0].id]

  tags = merge(local.base_tags, {
    Name = "${var.name}-vpce-ecr-api"
  })
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  count               = var.enable_ecr_vpc_endpoints ? 1 : 0
  vpc_id              = aws_vpc.this.id
  service_name        = data.aws_vpc_endpoint_service.ecr_dkr[0].service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = local.ssm_endpoint_subnet_ids
  security_group_ids = [aws_security_group.vpce[0].id]

  tags = merge(local.base_tags, {
    Name = "${var.name}-vpce-ecr-dkr"
  })
}

resource "aws_vpc_endpoint" "s3" {
  count             = var.enable_ecr_vpc_endpoints ? 1 : 0
  vpc_id            = aws_vpc.this.id
  service_name      = local.s3_gateway_service_name
  vpc_endpoint_type = "Gateway"

  # Only the public route table is explicitly associated in this module.
  # Private subnets use the VPC main route table unless you associate them elsewhere.
  route_table_ids = [
    aws_route_table.public.id,
    aws_vpc.this.main_route_table_id,
  ]

  tags = merge(local.base_tags, {
    Name = "${var.name}-vpce-s3"
  })
}

# NOTE:
# - Private subnets are created but not given a default route (no NAT here).
# - Add NAT gateways + private route tables later when required.
