output "public_ip" {
  value       = aws_instance.proxy.public_ip
  description = "Public IP of the egress proxy instance"
}

output "private_ip" {
  value       = aws_instance.proxy.private_ip
  description = "Private IP of the egress proxy instance"
}

output "security_group_id" {
  value       = aws_security_group.proxy.id
  description = "Security group id of the egress proxy"
}
