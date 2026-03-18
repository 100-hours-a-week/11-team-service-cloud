locals {
  base_tags = merge(var.tags, {
    Environment = var.environment
  })
}

resource "aws_lb" "nlb" {
  name               = "${var.name_prefix}-cp-nlb"
  internal           = var.internal
  load_balancer_type = "network"

  subnets = var.subnet_ids

  enable_deletion_protection = false

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-cp-nlb"
    Role = "k8s-control-plane-endpoint"
  })
}

resource "aws_lb_target_group" "apiserver" {
  name        = "${var.name_prefix}-cp-6443"
  port        = var.listener_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  # For TCP target groups, health checks default to TCP.
  health_check {
    protocol            = "TCP"
    port                = tostring(var.listener_port)
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-cp-6443"
  })
}

resource "aws_lb_listener" "apiserver" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = var.listener_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.apiserver.arn
  }
}

resource "aws_lb_target_group_attachment" "cp" {
  # NOTE: instance ids are typically unknown at plan time (created in the same apply),
  # so we must not use for_each with unknown keys. count works as long as list length
  # is known (e.g., from replicas).
  count = length(var.target_instance_ids)

  target_group_arn = aws_lb_target_group.apiserver.arn
  target_id        = var.target_instance_ids[count.index]
  port             = var.listener_port
}
