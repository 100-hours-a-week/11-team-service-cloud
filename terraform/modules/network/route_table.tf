# 퍼블릭 라우트 테이블

resource "aws_route_table" "prod_public" {
  vpc_id = aws_vpc.prod.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.prod.id
  }
  tags = {
    Name = "prod-public-rt"
  }
}

# 프라이빗 라우트 테이블 (NAT Gateway 없이 로컬 통신만)

resource "aws_route_table" "prod_private" {
  vpc_id = aws_vpc.prod.id
  tags = {
    Name = "prod-private-rt"
  }
}

resource "aws_route_table_association" "prod_app_private_a" {
  subnet_id      = aws_subnet.prod_app_private_a.id
  route_table_id = aws_route_table.prod_private.id
}

resource "aws_route_table_association" "prod_app_private_b" {
  subnet_id      = aws_subnet.prod_app_private_b.id
  route_table_id = aws_route_table.prod_private.id
}

resource "aws_route_table_association" "prod_db_private_a" {
  subnet_id      = aws_subnet.prod_db_private_a.id
  route_table_id = aws_route_table.prod_private.id
}

resource "aws_route_table_association" "prod_db_private_b" {
  subnet_id      = aws_subnet.prod_db_private_b.id
  route_table_id = aws_route_table.prod_private.id
}

# 라우트 테이블 연결

resource "aws_route_table_association" "prod_public_a" {
  subnet_id      = aws_subnet.prod_public_a.id
  route_table_id = aws_route_table.prod_public.id
}

resource "aws_route_table_association" "prod_public_b" {
  subnet_id      = aws_subnet.prod_public_b.id
  route_table_id = aws_route_table.prod_public.id
}
