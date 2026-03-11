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
