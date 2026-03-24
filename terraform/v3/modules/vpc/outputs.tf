output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID"
}

output "subnet_ids" {
  value       = { for name, s in aws_subnet.this : name => s.id }
  description = "Map of subnet name -> subnet id"
}

output "public_subnet_ids" {
  value       = [for name, s in aws_subnet.this : s.id if local.subnets_by_name[name].public]
  description = "Public subnet ids"
}

output "private_subnet_ids" {
  value       = [for name, s in aws_subnet.this : s.id if !local.subnets_by_name[name].public]
  description = "Private subnet ids"
}

output "ssm_vpc_endpoints_enabled" {
  value       = var.enable_ssm_vpc_endpoints
  description = "Whether SSM interface endpoints were requested"
}

output "ecr_vpc_endpoints_enabled" {
  value       = var.enable_ecr_vpc_endpoints
  description = "Whether ECR/S3 endpoints were requested"
}

output "vpce_security_group_id" {
  value       = (var.enable_ssm_vpc_endpoints || var.enable_ecr_vpc_endpoints) ? aws_security_group.vpce[0].id : null
  description = "Security group id for interface endpoints (if created)"
}
