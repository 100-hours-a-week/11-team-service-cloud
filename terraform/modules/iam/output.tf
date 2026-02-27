output "iam_instance_profile_name" {
  description = "IAM instance profile name for EC2 instances"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "iam_role_name" {
  description = "IAM role name attached to the instance profile"
  value       = aws_iam_role.ec2_role.name
}
