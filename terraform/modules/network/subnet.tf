locals {
  # We carve the /16 VPC into /21 subnets (adds 5 bits => 32 possible /21 blocks).
  # Index mapping (per env):
  #  0: public-a (ALB)
  #  1: public-b (ALB)
  #  2: web-private-a
  #  3: web-private-b
  #  4: app-private-a
  #  5: app-private-b
  #  6: data-private-a (RDS)
  #  7: data-private-b (RDS)
  subnet_newbits = 5

  has_az_b = length(var.azs) > 1

  cidrs = {
    public_a       = cidrsubnet(var.vpc_cidr, local.subnet_newbits, 0)
    public_b       = cidrsubnet(var.vpc_cidr, local.subnet_newbits, 1)
    web_private_a  = cidrsubnet(var.vpc_cidr, local.subnet_newbits, 2)
    web_private_b  = cidrsubnet(var.vpc_cidr, local.subnet_newbits, 3)
    app_private_a  = cidrsubnet(var.vpc_cidr, local.subnet_newbits, 4)
    app_private_b  = cidrsubnet(var.vpc_cidr, local.subnet_newbits, 5)
    data_private_a = cidrsubnet(var.vpc_cidr, local.subnet_newbits, 6)
    data_private_b = cidrsubnet(var.vpc_cidr, local.subnet_newbits, 7)
  }
}

# Public subnets (ALB)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.cidrs.public_a
  availability_zone       = var.azs[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.name_prefix}-public-${var.azs[0]}"
    Tier        = "public"
    Environment = var.environment
  }
}

resource "aws_subnet" "public_b" {
  count = local.has_az_b ? 1 : 0

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.cidrs.public_b
  availability_zone       = var.azs[1]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.name_prefix}-public-${var.azs[1]}"
    Tier        = "public"
    Environment = var.environment
  }
}

# Web private subnets (behind ALB)
resource "aws_subnet" "web_private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.cidrs.web_private_a
  availability_zone = var.azs[0]

  tags = {
    Name        = "${var.name_prefix}-web-private-${var.azs[0]}"
    Tier        = "web"
    Visibility  = "private"
    Environment = var.environment
  }
}

resource "aws_subnet" "web_private_b" {
  count = local.has_az_b ? 1 : 0

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.cidrs.web_private_b
  availability_zone = var.azs[1]

  tags = {
    Name        = "${var.name_prefix}-web-private-${var.azs[1]}"
    Tier        = "web"
    Visibility  = "private"
    Environment = var.environment
  }
}

# App private subnets
resource "aws_subnet" "app_private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.cidrs.app_private_a
  availability_zone = var.azs[0]

  tags = {
    Name        = "${var.name_prefix}-app-private-${var.azs[0]}"
    Tier        = "app"
    Visibility  = "private"
    Environment = var.environment
  }
}

resource "aws_subnet" "app_private_b" {
  count = local.has_az_b ? 1 : 0

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.cidrs.app_private_b
  availability_zone = var.azs[1]

  tags = {
    Name        = "${var.name_prefix}-app-private-${var.azs[1]}"
    Tier        = "app"
    Visibility  = "private"
    Environment = var.environment
  }
}

# Data private subnets (RDS)
resource "aws_subnet" "data_private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.cidrs.data_private_a
  availability_zone = var.azs[0]

  tags = {
    Name        = "${var.name_prefix}-data-private-${var.azs[0]}"
    Tier        = "data"
    Visibility  = "private"
    Environment = var.environment
  }
}

resource "aws_subnet" "data_private_b" {
  count = local.has_az_b ? 1 : 0

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.cidrs.data_private_b
  availability_zone = var.azs[1]

  tags = {
    Name        = "${var.name_prefix}-data-private-${var.azs[1]}"
    Tier        = "data"
    Visibility  = "private"
    Environment = var.environment
  }
}
