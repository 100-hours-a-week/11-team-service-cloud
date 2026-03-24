locals {
  base_tags = merge(var.tags, {
    Environment = var.environment
  })
}

# IAM role for SSM (so we can reach the instance without opening SSH)
resource "aws_iam_role" "ssm" {
  name = "${var.name_prefix}-cp-ssm-role"

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
    Name = "${var.name_prefix}-cp-ssm-role"
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.name_prefix}-cp-profile"
  role = aws_iam_role.ssm.name

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-cp-profile"
  })
}

resource "aws_security_group" "cp" {
  name        = "${var.name_prefix}-cp-sg"
  description = "Kubernetes control plane node"
  vpc_id      = var.vpc_id

  # kube-apiserver
  ingress {
    description = "kube-apiserver (6443)"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.allowed_api_cidrs
  }

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

  # NOTE: For a real cluster you'll likely want tighter rules and additional ports
  # (etcd, kubelet, node-to-control-plane traffic). Start permissive, then lock down.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-cp-sg"
    Role = "k8s-control-plane"
  })
}

resource "aws_instance" "cp" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.cp.id]

  iam_instance_profile = aws_iam_instance_profile.ssm.name
  key_name             = var.ssh_key_name

  user_data = var.control_plane_user_data

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-cp"
    Role = "k8s-control-plane"
  })
}
