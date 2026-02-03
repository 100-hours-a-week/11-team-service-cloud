output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.bigbang_instance.id
}

output "instance_public_ip" {
  description = "EC2 instance public IP"
  value       = aws_instance.bigbang_instance.public_ip
}

output "instance_private_ip" {
  description = "EC2 instance private IP"
  value       = aws_instance.bigbang_instance.private_ip
}
