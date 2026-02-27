resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name        = "${var.name_prefix}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "${var.name_prefix}-private-rt"
    Environment = var.environment
  }
}

# Associate public route table
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  count = length(aws_subnet.public_b) > 0 ? 1 : 0

  subnet_id      = aws_subnet.public_b[0].id
  route_table_id = aws_route_table.public.id
}

# Associate private route table (no NAT)
resource "aws_route_table_association" "web_private_a" {
  subnet_id      = aws_subnet.web_private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "web_private_b" {
  count = length(aws_subnet.web_private_b) > 0 ? 1 : 0

  subnet_id      = aws_subnet.web_private_b[0].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "app_private_a" {
  subnet_id      = aws_subnet.app_private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "app_private_b" {
  count = length(aws_subnet.app_private_b) > 0 ? 1 : 0

  subnet_id      = aws_subnet.app_private_b[0].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "data_private_a" {
  subnet_id      = aws_subnet.data_private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "data_private_b" {
  count = length(aws_subnet.data_private_b) > 0 ? 1 : 0

  subnet_id      = aws_subnet.data_private_b[0].id
  route_table_id = aws_route_table.private.id
}
