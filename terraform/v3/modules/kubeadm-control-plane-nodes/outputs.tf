output "instance_ids" {
  value       = [for k in sort(keys(aws_instance.cp)) : aws_instance.cp[k].id]
  description = "Control plane instance ids"
}

output "private_ips" {
  value       = [for k in sort(keys(aws_instance.cp)) : aws_instance.cp[k].private_ip]
  description = "Control plane private IPs"
}

output "security_group_id" {
  value       = aws_security_group.cp.id
  description = "Control plane security group id"
}
