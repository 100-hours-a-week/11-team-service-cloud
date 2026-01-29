# ----------
# VPC
# ----------
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.prod.id
}

# ----------
# Subnet
# ----------
output "public_subnet_a_id" {
  description = "Public subnet A ID"
  value       = aws_subnet.prod_public_a.id
}

output "public_subnet_b_id" {
  description = "Public subnet B ID"
  value       = aws_subnet.prod_public_b.id
}

output "app_private_subnet_a_id" {
  description = "App private subnet A ID"
  value       = aws_subnet.prod_app_private_a.id
}

output "app_private_subnet_b_id" {
  description = "App private subnet B ID"
  value       = aws_subnet.prod_app_private_b.id
}

output "db_private_subnet_a_id" {
  description = "DB private subnet A ID"
  value       = aws_subnet.prod_db_private_a.id
}

output "db_private_subnet_b_id" {
  description = "DB private subnet B ID"
  value       = aws_subnet.prod_db_private_b.id
}

# ----------------
# Security Group
# ----------------
output "security_group_id" {
  description = "Bigbang security group ID"
  value       = aws_security_group.bigbang.id
}

# --------
# EIP 
# --------
output "eip_id" {
  description = "Elastic IP ID"
  value       = aws_eip.bigbang.id
}

output "eip_public_ip" {
  description = "Elastic IP address"
  value       = aws_eip.bigbang.public_ip
}