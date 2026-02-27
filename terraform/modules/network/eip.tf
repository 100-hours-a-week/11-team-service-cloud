resource "aws_eip" "bigbang" {
  count  = var.create_eip ? 1 : 0
  domain = "vpc"

  tags = {
    Name        = "${var.name_prefix}-bigbang-eip"
    Environment = var.environment
  }
}
