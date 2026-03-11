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

# NOTE:
# - Private subnets are created but not given a default route (no NAT here).
# - Add NAT gateways + private route tables later when required.
