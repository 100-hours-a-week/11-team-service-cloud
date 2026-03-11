locals {
  base_tags = merge(var.tags, {
    Environment = var.environment
  })
}

# Ubuntu 24.04 AMI via SSM Parameter (region-safe)
data "aws_ssm_parameter" "ubuntu_2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

locals {
  effective_ami_id = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.ubuntu_2404_ami.value
}

# IAM role for SSM (so we can reach the builder without opening SSH)
resource "aws_iam_role" "ssm" {
  name = "${var.name_prefix}-ami-builder-ssm-role"

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
    Name = "${var.name_prefix}-ami-builder-ssm-role"
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.name_prefix}-ami-builder-profile"
  role = aws_iam_role.ssm.name

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-ami-builder-profile"
  })
}

resource "aws_security_group" "builder" {
  name        = "${var.name_prefix}-ami-builder-sg"
  description = "Golden AMI builder instance"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH (optional)"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-ami-builder-sg"
  })
}

resource "aws_instance" "builder" {
  ami                    = local.effective_ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.builder.id]

  iam_instance_profile = aws_iam_instance_profile.ssm.name

  key_name = var.ssh_key_name

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    k8s_minor_version = var.k8s_minor_version
    helm_version      = var.helm_version
    enable_proxy      = var.enable_proxy
    proxy_private_ip  = var.proxy_private_ip
    proxy_port        = var.proxy_port
    no_proxy          = var.no_proxy
    pause_image       = var.pause_image
  })

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-ami-builder"
    Role = "ami-builder"
  })
}
