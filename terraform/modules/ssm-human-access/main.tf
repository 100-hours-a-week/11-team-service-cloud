data "aws_iam_role" "target" {
  for_each = toset(var.role_names)
  name     = each.key
}

resource "aws_iam_policy" "ssm_session" {
  name        = var.policy_name
  description = "Allow Session Manager and RunCommand for project roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:StartSession",
          "ssm:ResumeSession",
          "ssm:TerminateSession",
          "ssm:DescribeSessions",
          "ssm:GetConnectionStatus",
          "ssm:DescribeInstanceInformation",
          "ssm:DescribeInstanceProperties",
          "ssm:SendCommand",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations",
          "ssm:GetCommandInvocation",
          "ssm:DescribeDocument",
          "ssm:GetDocument"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  for_each   = data.aws_iam_role.target
  role       = each.value.name
  policy_arn = aws_iam_policy.ssm_session.arn
}
