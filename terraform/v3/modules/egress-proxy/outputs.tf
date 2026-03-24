output "public_ip" {
  value       = try(values(aws_instance.proxy)[0].public_ip, null)
  description = "(Compat) Public IP of the first egress proxy instance"
}

output "private_ip" {
  value       = try(values(aws_instance.proxy)[0].private_ip, null)
  description = "(Compat) Private IP of the first egress proxy instance"
}

output "public_ips" {
  value       = [for i in values(aws_instance.proxy) : i.public_ip]
  description = "Public IPs of the egress proxy instances"
}

output "private_ips" {
  value       = [for i in values(aws_instance.proxy) : i.private_ip]
  description = "Private IPs of the egress proxy instances"
}

output "endpoint_dns_name" {
  value       = var.enable_nlb ? aws_lb.proxy[0].dns_name : null
  description = "Internal NLB DNS name for the egress proxy (null when enable_nlb=false)"
}

output "endpoint_port" {
  value       = var.proxy_port
  description = "Port for the egress proxy endpoint"
}

output "security_group_id" {
  value       = aws_security_group.proxy.id
  description = "Security group id of the egress proxy"
}
