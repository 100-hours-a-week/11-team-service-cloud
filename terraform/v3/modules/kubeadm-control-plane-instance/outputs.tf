output "instance_id" {
  value       = aws_instance.cp.id
  description = "Control plane instance id"
}

output "private_ip" {
  value       = aws_instance.cp.private_ip
  description = "Control plane private IP"
}

output "security_group_id" {
  value       = aws_security_group.cp.id
  description = "Control plane security group id"
}
