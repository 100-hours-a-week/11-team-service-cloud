output "alb_dns_name" {
  value       = aws_lb.public.dns_name
  description = "Public ALB DNS"
}

output "alb_arn" {
  value       = aws_lb.public.arn
  description = "ALB ARN"
}

output "target_group_arn" {
  value       = aws_lb_target_group.workers_nodeport.arn
  description = "Target group ARN"
}

output "workers_asg_name" {
  value       = aws_autoscaling_group.workers.name
  description = "Workers ASG name"
}

output "alb_security_group_id" {
  value       = aws_security_group.alb.id
  description = "ALB SG id"
}

output "workers_security_group_id" {
  value       = aws_security_group.workers.id
  description = "Workers SG id"
}
