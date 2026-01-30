data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# EC2 인스턴스가 Parameter Store에 접근할 수 있도록 IAM 역할 생성

# IAM 역할 생성
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-ssm-role"

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
    Name = "ec2-ssm-role"
  }
}

# Parameter Store 읽기 권한 정책
resource "aws_iam_role_policy" "ssm_read_policy" {
  name = "ssm-read-policy"
  role = aws_iam_role.ec2_ssm_role.id

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
        Resource = "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter/bigbang/*"
      }
    ]
  })
}

# S3 접근 권한 정책 (배포를 위해)
resource "aws_iam_role_policy" "s3_read_policy" {
  name = "s3-read-policy"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # ListBucket 권한 (bucket 단위)
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
      # GetObject 권한 (object 단위)
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

# IAM 인스턴스 프로필 생성
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name

  tags = {
    Name = "ec2-ssm-profile"
  }
}
