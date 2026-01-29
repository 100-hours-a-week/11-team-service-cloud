# EIP 생성

resource "aws_eip" "bigbang" {
  domain = "vpc"
  tags = {
    Name = "bigbang-eip"
  }
}

# EIP 할당

resource "aws_eip_association" "bigbang" {
  allocation_id = aws_eip.bigbang.id
  instance_id   = aws_instance.bigbang_instance.id
}