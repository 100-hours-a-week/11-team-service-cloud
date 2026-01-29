# 퍼블릭 서브넷

resource "aws_subnet" "prod_public_a" {
  vpc_id                          = aws_vpc.prod.id
  cidr_block                      = "10.0.1.0/24"
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.prod.ipv6_cidr_block, 8, 1)
  availability_zone               = "ap-northeast-2a"
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true
  tags = {
    Name = "prod-public-subnet-a"
  }
}

resource "aws_subnet" "prod_public_b" {
  vpc_id                          = aws_vpc.prod.id
  cidr_block                      = "10.0.2.0/24"
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.prod.ipv6_cidr_block, 8, 2)
  availability_zone               = "ap-northeast-2b"
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true
  tags = {
    Name = "prod-public-subnet-b"
  }
}

# 프라이빗 APP 서브넷

resource "aws_subnet" "prod_app_private_a" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.0.8.0/21"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "prod-app-private-subnet-a"
  }
}

resource "aws_subnet" "prod_app_private_b" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.0.16.0/21"
  availability_zone = "ap-northeast-2b"
  tags = {
    Name = "prod-app-private-subnet-b"
  }
}

# 프라이빗 DB 서브넷

resource "aws_subnet" "prod_db_private_a" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "prod-db-private-subnet-a"
  }
}

resource "aws_subnet" "prod_db_private_b" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-northeast-2b"
  tags = {
    Name = "prod-db-private-subnet-b"
  }
}
