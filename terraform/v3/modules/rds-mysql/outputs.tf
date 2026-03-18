output "endpoint" {
  value       = aws_db_instance.this.address
  description = "RDS endpoint address"
}

output "port" {
  value       = aws_db_instance.this.port
  description = "RDS port"
}

output "identifier" {
  value       = aws_db_instance.this.identifier
  description = "RDS identifier"
}
