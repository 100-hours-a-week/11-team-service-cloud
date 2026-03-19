locals {
  base_tags = merge(var.tags, {
    Environment = var.environment
  })
}

# --------------------------------------
# Security Groups
# --------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-alb-sg"
  })
}

resource "aws_security_group" "workers" {
  name        = "${var.name_prefix}-workers-sg"
  description = "Kubernetes worker nodes"
  vpc_id      = var.vpc_id

  # NOTE: Manage ingress rules via aws_security_group_rule resources to avoid
  # conflicts/drift with additional rules created elsewhere (Calico, kubelet, etc.).

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-workers-sg"
  })
}

# ALB -> Worker NodePort
resource "aws_security_group_rule" "workers_nodeport_from_alb" {
  type              = "ingress"
  security_group_id = aws_security_group.workers.id

  protocol  = "tcp"
  from_port = var.nodeport_http
  to_port   = var.nodeport_http

  source_security_group_id = aws_security_group.alb.id
  description              = "NodePort from ALB"
}

# --------------------------------------
# ALB + Target Group
# --------------------------------------
resource "aws_lb" "public" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb.id]
  subnets         = var.public_subnet_ids

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-alb"
  })
}

resource "aws_lb_target_group" "workers_nodeport" {
  name        = "${var.name_prefix}-workers-np"
  port        = var.nodeport_http
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-workers-np"
  })
}

# HTTP -> HTTPS redirect
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.workers_nodeport.arn
  }
}

# --------------------------------------
# Worker Nodes ASG
# --------------------------------------
# Ubuntu 24.04 AMI via SSM Parameter (region-safe)
data "aws_ssm_parameter" "ubuntu_2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

locals {
  effective_worker_ami_id = var.worker_ami_id != null ? var.worker_ami_id : data.aws_ssm_parameter.ubuntu_2404_ami.value

  effective_worker_user_data = var.worker_user_data != null ? var.worker_user_data : templatefile("${path.module}/worker_join_user_data.sh.tftpl", {
    control_plane_endpoint                        = var.control_plane_endpoint
    kubeadm_join_token_ssm_param_name             = var.kubeadm_join_token_ssm_param_name
    kubeadm_ca_hash_ssm_param_name                = var.kubeadm_ca_hash_ssm_param_name
    kubeadm_control_plane_endpoint_ssm_param_name = var.kubeadm_control_plane_endpoint_ssm_param_name
    http_proxy                                    = var.http_proxy
    https_proxy                                   = var.https_proxy
    no_proxy                                      = var.no_proxy
  })
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Worker IAM role (SSM + read join params)
resource "aws_iam_role" "workers" {
  name = "${var.name_prefix}-workers-role"

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
    Name = "${var.name_prefix}-workers-role"
  })
}

resource "aws_iam_role_policy_attachment" "workers_ssm" {
  role       = aws_iam_role.workers.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allow worker nodes to pull images from private ECR repositories
resource "aws_iam_role_policy_attachment" "workers_ecr_readonly" {
  role       = aws_iam_role.workers.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy" "workers_read_join_params" {
  name = "${var.name_prefix}-workers-read-join-params"
  role = aws_iam_role.workers.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = compact([
          var.kubeadm_join_token_ssm_param_name != null ? "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter${var.kubeadm_join_token_ssm_param_name}" : null,
          var.kubeadm_ca_hash_ssm_param_name != null ? "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter${var.kubeadm_ca_hash_ssm_param_name}" : null
        ])
      }
    ]
  })
}

# Cluster Autoscaler permissions (when running autoscaler on nodes with this instance profile)
resource "aws_iam_role_policy" "workers_cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name = "${var.name_prefix}-workers-cluster-autoscaler"
  role = aws_iam_role.workers.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "workers" {
  name = "${var.name_prefix}-workers-profile"
  role = aws_iam_role.workers.name

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-workers-profile"
  })
}

resource "aws_launch_template" "workers" {
  name_prefix   = "${var.name_prefix}-workers-"
  image_id      = local.effective_worker_ami_id
  instance_type = var.worker_instance_type

  key_name = var.ssh_key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.workers.name
  }

  vpc_security_group_ids = [aws_security_group.workers.id]

  # Root EBS volume size
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.worker_root_volume_size_gb
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  user_data = base64encode(local.effective_worker_user_data)

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.base_tags, {
      Name = "${var.name_prefix}-worker"
      Role = "k8s-worker"
    })
  }
}

resource "aws_autoscaling_group" "workers" {
  name                = "${var.name_prefix}-workers-asg"
  vpc_zone_identifier = var.worker_subnet_ids

  min_size         = var.workers_min
  desired_capacity = var.workers_desired
  max_size         = var.workers_max

  health_check_type = "EC2"

  launch_template {
    id      = aws_launch_template.workers.id
    version = "$Latest"
  }

  # Automatically roll instances when the launch template changes.
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }

    # triggers omitted (launch_template changes already trigger refresh)
  }

  # Attach target group so instances are auto-registered/de-registered
  target_group_arns = [aws_lb_target_group.workers_nodeport.arn]

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-worker"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.enable_cluster_autoscaler && var.cluster_name != null ? [1] : []
    content {
      key                 = "k8s.io/cluster-autoscaler/enabled"
      value               = "true"
      propagate_at_launch = true
    }
  }

  dynamic "tag" {
    for_each = var.enable_cluster_autoscaler && var.cluster_name != null ? [1] : []
    content {
      key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
      value               = "owned"
      propagate_at_launch = true
    }
  }
}
