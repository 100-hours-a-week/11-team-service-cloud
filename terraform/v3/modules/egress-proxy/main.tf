locals {
  base_tags = merge(var.tags, {
    Environment = var.environment
  })
}

# Ubuntu 24.04 AMI via SSM Parameter (region-safe)
data "aws_ssm_parameter" "ubuntu_2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

locals {
  effective_ami_id = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.ubuntu_2404_ami.value

  effective_subnet_ids = var.subnet_ids != null ? var.subnet_ids : compact([var.subnet_id])
}

resource "aws_security_group" "proxy" {
  name        = "${var.name_prefix}-egress-proxy-sg"
  description = "Forward proxy in public subnet for private instances"
  vpc_id      = var.vpc_id

  ingress {
    description = "Proxy from VPC"
    from_port   = var.proxy_port
    to_port     = var.proxy_port
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }

  ingress {
    description = "Node Exporter from VPC"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-egress-proxy-sg"
  })
}

# IAM role for SSM (so we can reach the proxy without opening SSH)
resource "aws_iam_role" "ssm" {
  name = "${var.name_prefix}-egress-proxy-ssm-role"

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
    Name = "${var.name_prefix}-egress-proxy-ssm-role"
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.name_prefix}-egress-proxy-profile"
  role = aws_iam_role.ssm.name

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-egress-proxy-profile"
  })
}

resource "aws_instance" "proxy" {
  for_each = toset(local.effective_subnet_ids)

  ami                    = local.effective_ami_id
  instance_type          = var.instance_type
  subnet_id              = each.value
  vpc_security_group_ids = [aws_security_group.proxy.id]

  iam_instance_profile = aws_iam_instance_profile.ssm.name

  associate_public_ip_address = true
  key_name                    = var.ssh_key_name

  user_data = <<-EOF
#!/bin/bash
set -euo pipefail
exec > /var/log/user-data.log 2>&1
set -x

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y squid snapd

# Install + start SSM agent (snap)
systemctl enable --now snapd || true
snap install amazon-ssm-agent --classic || true
systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true

cat >/etc/squid/squid.conf <<CONF
http_port ${var.proxy_port}

# Client allowlist
acl allowed_vpc src ${data.aws_vpc.this.cidr_block}

%{if var.allow_all}
# Destination: allow ALL
%{else}
# Destination allowlist (domains)
acl allowed_domains dstdomain ${join(" ", var.allowed_domains)}
%{endif}

# Ports hardening
acl SSL_ports port 443
acl Safe_ports port 80 443
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports

%{if var.allow_all}
http_access allow allowed_vpc
%{else}
http_access allow allowed_vpc allowed_domains
%{endif}

http_access deny all

forwarded_for delete
via off

access_log /var/log/squid/access.log
cache_log /var/log/squid/cache.log
CONF

systemctl enable --now squid
systemctl restart squid
EOF

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-egress-proxy-${replace(each.value, "subnet-", "")}"
  })
}

# --------------------------------------
# Internal NLB endpoint for proxy (one stable DNS)
# --------------------------------------
resource "aws_lb" "proxy" {
  count              = var.enable_nlb ? 1 : 0
  name               = "${var.name_prefix}-egress-proxy"
  load_balancer_type = "network"
  internal           = true
  subnets            = local.effective_subnet_ids

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-egress-proxy-nlb"
  })
}

resource "aws_lb_target_group" "proxy" {
  count       = var.enable_nlb ? 1 : 0
  name        = "${var.name_prefix}-egress-proxy"
  port        = var.proxy_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol = "TCP"
    port     = tostring(var.proxy_port)
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-egress-proxy-tg"
  })
}

resource "aws_lb_target_group_attachment" "proxy" {
  for_each = var.enable_nlb ? aws_instance.proxy : {}

  target_group_arn = aws_lb_target_group.proxy[0].arn
  target_id        = each.value.id
  port             = var.proxy_port
}

resource "aws_lb_listener" "proxy" {
  count             = var.enable_nlb ? 1 : 0
  load_balancer_arn = aws_lb.proxy[0].arn
  port              = var.proxy_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.proxy[0].arn
  }
}
