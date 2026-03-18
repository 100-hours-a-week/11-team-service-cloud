locals {
  base_tags = merge(var.tags, {
    Environment = var.environment
  })

  indexes = toset([for i in range(var.replicas) : tostring(i)])

  # Round-robin placement across provided subnets
  subnet_by_index = {
    for i in range(var.replicas) :
    tostring(i) => var.subnet_ids[i % length(var.subnet_ids)]
  }
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

# Allow control-plane instances (used as an admin/bastion via SSM) to pull from ECR
# and to generate ECR auth tokens (useful for creating imagePullSecrets).
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "ssm_put_parameter" {
  count = length(var.ssm_put_parameter_names) > 0 ? 1 : 0

  name = "${var.name_prefix}-cp-ssm-put-parameter"
  role = aws_iam_role.ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:AddTagsToResource"
        ]
        Resource = [
          for n in var.ssm_put_parameter_names : "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter${n}"
        ]
      }
    ]
  })
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
  description = "Kubernetes control plane nodes"
  vpc_id      = var.vpc_id

  # NOTE: Manage ingress rules via aws_security_group_rule resources to avoid
  # conflicts/drift with additional rules created elsewhere.

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

# kube-apiserver (6443)
# One rule per CIDR avoids duplicate/replace issues and makes import easier.
resource "aws_security_group_rule" "cp_apiserver_6443" {
  for_each = toset(var.allowed_api_cidrs)

  type              = "ingress"
  security_group_id = aws_security_group.cp.id

  protocol  = "tcp"
  from_port = 6443
  to_port   = 6443

  cidr_blocks = [each.value]
  description = "kube-apiserver (6443)"
}

# SSH (optional)
resource "aws_security_group_rule" "cp_ssh" {
  count             = length(var.allowed_ssh_cidrs) > 0 ? 1 : 0
  type              = "ingress"
  security_group_id = aws_security_group.cp.id

  protocol  = "tcp"
  from_port = 22
  to_port   = 22

  cidr_blocks = var.allowed_ssh_cidrs
  description = "SSH (optional)"
}

resource "aws_instance" "cp" {
  for_each = local.indexes

  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = local.subnet_by_index[each.key]
  vpc_security_group_ids = [aws_security_group.cp.id]

  iam_instance_profile = aws_iam_instance_profile.ssm.name
  key_name             = var.ssh_key_name

  user_data = var.control_plane_user_data

  tags = merge(local.base_tags, {
    Name  = "${var.name_prefix}-cp-${each.key}"
    Role  = "k8s-control-plane"
    Index = each.key
  })
}
