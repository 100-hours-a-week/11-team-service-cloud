# NAT Gateway is intentionally not used.
# To allow private subnets to access AWS services (SSM, ECR, CloudWatch Logs, STS, S3),
# we provision VPC endpoints.

data "aws_region" "current" {}

# Gateway endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.private.id]

  tags = {
    Name        = "${var.name_prefix}-s3-endpoint"
    Environment = var.environment
  }
}

# Interface endpoints for SSM / ECR / Logs / STS
locals {
  interface_endpoints = [
    "ssm",
    "ec2messages",
    "ssmmessages",
    "logs",
    "ecr.api",
    "ecr.dkr",
    "sts",
  ]
}

resource "aws_security_group" "endpoints" {
  name        = "${var.name_prefix}-endpoints-sg"
  description = "VPC interface endpoints security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name_prefix}-endpoints-sg"
    Environment = var.environment
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.interface_endpoints)

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  # Interface endpoints require subnets in *different AZs* (one per AZ).
  # Put them in the app private subnets (instances in the VPC can still reach them via private DNS).
  subnet_ids = concat(
    [aws_subnet.app_private_a.id],
    length(aws_subnet.app_private_b) > 0 ? [aws_subnet.app_private_b[0].id] : []
  )
  security_group_ids = [aws_security_group.endpoints.id]

  tags = {
    Name        = "${var.name_prefix}-${replace(each.key, ".", "-")}-endpoint"
    Environment = var.environment
  }
}
