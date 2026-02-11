output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID"
}

output "public_subnet_ids" {
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  description = "Public subnet IDs (for ALB)"
}

# Legacy single outputs
output "public_subnet_a_id" {
  value       = aws_subnet.public_a.id
  description = "(Legacy) Public subnet A ID"
}

output "public_subnet_b_id" {
  value       = aws_subnet.public_b.id
  description = "(Legacy) Public subnet B ID"
}

output "web_private_subnet_ids" {
  value       = [aws_subnet.web_private_a.id, aws_subnet.web_private_b.id]
  description = "Web private subnet IDs"
}

output "app_private_subnet_ids" {
  value       = [aws_subnet.app_private_a.id, aws_subnet.app_private_b.id]
  description = "App private subnet IDs"
}

output "data_private_subnet_ids" {
  value       = [aws_subnet.data_private_a.id, aws_subnet.data_private_b.id]
  description = "Data private subnet IDs (for RDS)"
}

output "app_private_subnet_a_id" {
  value       = aws_subnet.app_private_a.id
  description = "(Legacy) App private subnet A ID"
}

output "app_private_subnet_b_id" {
  value       = aws_subnet.app_private_b.id
  description = "(Legacy) App private subnet B ID"
}

output "db_private_subnet_a_id" {
  value       = aws_subnet.data_private_a.id
  description = "(Legacy) DB private subnet A ID"
}

output "db_private_subnet_b_id" {
  value       = aws_subnet.data_private_b.id
  description = "(Legacy) DB private subnet B ID"
}

output "alb_security_group_id" {
  value       = aws_security_group.alb.id
  description = "ALB security group ID"
}

output "web_security_group_id" {
  value       = aws_security_group.web.id
  description = "Web instances security group ID"
}

output "app_spring_security_group_id" {
  value       = aws_security_group.app_spring.id
  description = "Spring app instances security group ID"
}

output "app_ai_security_group_id" {
  value       = aws_security_group.app_ai.id
  description = "AI app instances security group ID"
}

# Legacy name for older callers
output "app_security_group_id" {
  value       = aws_security_group.app_spring.id
  description = "(Legacy) App security group ID"
}

output "rds_security_group_id" {
  value       = aws_security_group.rds.id
  description = "RDS security group ID"
}

# Legacy: EIP outputs (used by older single-instance setup)
output "eip_id" {
  value       = try(aws_eip.bigbang[0].id, null)
  description = "Elastic IP allocation id (legacy)"
}

output "eip_public_ip" {
  value       = try(aws_eip.bigbang[0].public_ip, null)
  description = "Elastic IP address (legacy)"
}
