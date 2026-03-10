output "policy_arn" {
  description = "Policy ARN that was attached"
  value       = aws_iam_policy.ssm_session.arn
}
