data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# EC2 instances need an instance profile role for:
# - SSM (Session Manager)
# - optional S3 read (deployment artifacts)
# - optional Parameter Store read

resource "aws_iam_role" "ec2_role" {
  name = "${var.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.name_prefix}-ec2-role"
  }
}

# Attach the AWS managed policy required for SSM Managed Instances
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allow instances to authenticate to ECR and pull images
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Parameter Store read (scoped by prefix)
resource "aws_iam_role_policy" "ssm_read_policy" {
  name = "ssm-read-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${trimprefix(var.ssm_parameter_prefix, "/") == "" ? "" : "/"}${trimprefix(var.ssm_parameter_prefix, "/")}*"
      }
    ]
  })
}

# S3 read for deployment buckets (optional)
resource "aws_iam_role_policy" "s3_read_policy" {
  count = length(var.deployment_buckets) > 0 ? 1 : 0

  name = "s3-read-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        for bucket in var.deployment_buckets : {
          Effect = "Allow"
          Action = [
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ]
          Resource = "arn:aws:s3:::${bucket}"
        }
      ],
      [
        for bucket in var.deployment_buckets : {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion"
          ]
          Resource = "arn:aws:s3:::${bucket}/*"
        }
      ]
    )
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name = "${var.name_prefix}-ec2-profile"
  }
}
