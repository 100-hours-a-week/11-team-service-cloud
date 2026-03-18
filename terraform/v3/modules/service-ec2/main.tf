locals {
  base_tags = merge(var.tags, {
    Environment = var.environment
    Service     = var.service_name
  })

  name = "${var.name_prefix}-${var.service_name}"
}

# IAM role for SSM access
resource "aws_iam_role" "ssm" {
  name = "${local.name}-ssm-role"

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

  tags = merge(local.base_tags, {
    Name = "${local.name}-ssm-role"
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allow pulling images from ECR (if docker-compose uses ECR images)
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  count      = var.enable_ecr_readonly ? 1 : 0
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Allow reading deployment assets (e.g., docker-compose.yml) from S3
resource "aws_iam_role_policy" "s3_read" {
  count = length(var.s3_read_buckets) > 0 ? 1 : 0

  name = "${local.name}-s3-read"
  role = aws_iam_role.ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        for bucket in var.s3_read_buckets : {
          Effect = "Allow"
          Action = [
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ]
          Resource = "arn:aws:s3:::${bucket}"
        }
      ],
      [
        for bucket in var.s3_read_buckets : {
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

resource "aws_iam_instance_profile" "this" {
  name = "${local.name}-profile"
  role = aws_iam_role.ssm.name

  tags = merge(local.base_tags, {
    Name = "${local.name}-profile"
  })
}

resource "aws_security_group" "this" {
  name        = "${local.name}-sg"
  description = "${var.service_name} service instance"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, {
    Name = "${local.name}-sg"
    Tier = "data"
  })
}

resource "aws_security_group_rule" "ingress" {
  for_each = toset([for p in var.ingress_ports : tostring(p)])

  type              = "ingress"
  security_group_id = aws_security_group.this.id

  protocol  = "tcp"
  from_port = tonumber(each.key)
  to_port   = tonumber(each.key)

  source_security_group_id = var.ingress_from_security_group_id
  description              = "Allow ${var.service_name} from k8s workers"
}

resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]

  iam_instance_profile = aws_iam_instance_profile.this.name
  key_name             = var.ssh_key_name

  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = var.user_data

  tags = merge(local.base_tags, {
    Name = local.name
  })
}
