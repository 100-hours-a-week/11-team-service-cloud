output "instance_id" {
  value       = aws_instance.builder.id
  description = "AMI builder instance id"
}

output "private_ip" {
  value       = aws_instance.builder.private_ip
  description = "AMI builder private ip"
}

output "security_group_id" {
  value       = aws_security_group.builder.id
  description = "Builder security group id"
}
