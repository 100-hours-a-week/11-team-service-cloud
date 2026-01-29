# EIP 생성

resource "aws_eip" "bigbang" {
  domain = "vpc"
  tags = {
    Name = "bigbang-eip"
  }
}
