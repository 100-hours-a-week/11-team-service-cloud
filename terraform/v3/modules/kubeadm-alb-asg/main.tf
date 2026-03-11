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

  # ALB -> NodePort
  ingress {
    description     = "NodePort from ALB"
    from_port       = var.nodeport_http
    to_port         = var.nodeport_http
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # TODO: extend to allow cluster internal traffic as needed.
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
data "aws_ssm_parameter" "ubuntu_2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_launch_template" "workers" {
  name_prefix   = "${var.name_prefix}-workers-"
  image_id      = data.aws_ssm_parameter.ubuntu_2404_ami.value
  instance_type = var.worker_instance_type

  key_name = var.ssh_key_name

  vpc_security_group_ids = [aws_security_group.workers.id]

  # NOTE: kubeadm join automation should be added here.
  user_data = base64encode(var.worker_user_data)

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

  # Attach target group so instances are auto-registered/de-registered
  target_group_arns = [aws_lb_target_group.workers_nodeport.arn]

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-worker"
    propagate_at_launch = true
  }
}
