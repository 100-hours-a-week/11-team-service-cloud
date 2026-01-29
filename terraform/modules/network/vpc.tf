# VPC 생성

resource "aws_vpc" "prod" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true

  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "prod-vpc"
  }
}