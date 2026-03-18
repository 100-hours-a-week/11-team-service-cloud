output "dns_name" {
  value       = aws_lb.nlb.dns_name
  description = "Public NLB DNS name for kube-apiserver endpoint"
}

output "arn" {
  value       = aws_lb.nlb.arn
  description = "NLB ARN"
}

output "target_group_arn" {
  value       = aws_lb_target_group.apiserver.arn
  description = "Target group ARN"
}
