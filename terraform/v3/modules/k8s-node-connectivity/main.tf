locals {
  desc_prefix = var.name_prefix
}

# -------------------------
# Calico BGP (TCP/179)
# -------------------------
resource "aws_security_group_rule" "workers_bgp_self" {
  count             = var.enable_calico_bgp ? 1 : 0
  type              = "ingress"
  security_group_id = var.workers_sg_id

  protocol  = "tcp"
  from_port = 179
  to_port   = 179

  source_security_group_id = var.workers_sg_id
  description              = "${local.desc_prefix}: Calico BGP (TCP/179) within workers"
}

resource "aws_security_group_rule" "cp_bgp_self" {
  count             = var.enable_calico_bgp ? 1 : 0
  type              = "ingress"
  security_group_id = var.control_plane_sg_id

  protocol  = "tcp"
  from_port = 179
  to_port   = 179

  source_security_group_id = var.control_plane_sg_id
  description              = "${local.desc_prefix}: Calico BGP (TCP/179) within control plane"
}

resource "aws_security_group_rule" "cp_bgp_from_workers" {
  count             = var.enable_calico_bgp ? 1 : 0
  type              = "ingress"
  security_group_id = var.control_plane_sg_id

  protocol  = "tcp"
  from_port = 179
  to_port   = 179

  source_security_group_id = var.workers_sg_id
  description              = "${local.desc_prefix}: Calico BGP (TCP/179) workers to control plane"
}

resource "aws_security_group_rule" "workers_bgp_from_cp" {
  count             = var.enable_calico_bgp ? 1 : 0
  type              = "ingress"
  security_group_id = var.workers_sg_id

  protocol  = "tcp"
  from_port = 179
  to_port   = 179

  source_security_group_id = var.control_plane_sg_id
  description              = "${local.desc_prefix}: Calico BGP (TCP/179) control plane to workers"
}

# -------------------------
# IP-in-IP (protocol 4)
# -------------------------
resource "aws_security_group_rule" "workers_ipip_self" {
  count             = var.enable_ipip ? 1 : 0
  type              = "ingress"
  security_group_id = var.workers_sg_id

  protocol  = "4"
  from_port = 0
  to_port   = 0

  source_security_group_id = var.workers_sg_id
  description              = "${local.desc_prefix}: Calico IPIP (protocol 4) within workers"
}

resource "aws_security_group_rule" "cp_ipip_self" {
  count             = var.enable_ipip ? 1 : 0
  type              = "ingress"
  security_group_id = var.control_plane_sg_id

  protocol  = "4"
  from_port = 0
  to_port   = 0

  source_security_group_id = var.control_plane_sg_id
  description              = "${local.desc_prefix}: Calico IPIP (protocol 4) within control plane"
}

resource "aws_security_group_rule" "cp_ipip_from_workers" {
  count             = var.enable_ipip ? 1 : 0
  type              = "ingress"
  security_group_id = var.control_plane_sg_id

  protocol  = "4"
  from_port = 0
  to_port   = 0

  source_security_group_id = var.workers_sg_id
  description              = "${local.desc_prefix}: Calico IPIP (protocol 4) workers to control plane"
}

resource "aws_security_group_rule" "workers_ipip_from_cp" {
  count             = var.enable_ipip ? 1 : 0
  type              = "ingress"
  security_group_id = var.workers_sg_id

  protocol  = "4"
  from_port = 0
  to_port   = 0

  source_security_group_id = var.control_plane_sg_id
  description              = "${local.desc_prefix}: Calico IPIP (protocol 4) control plane to workers"
}

# -------------------------
# kubelet HTTPS (TCP/10250)
# -------------------------
resource "aws_security_group_rule" "workers_kubelet_10250_self" {
  count             = var.enable_kubelet_10250 ? 1 : 0
  type              = "ingress"
  security_group_id = var.workers_sg_id

  protocol  = "tcp"
  from_port = 10250
  to_port   = 10250

  source_security_group_id = var.workers_sg_id
  description              = "${local.desc_prefix}: kubelet HTTPS (TCP/10250) within workers"
}

resource "aws_security_group_rule" "workers_kubelet_10250_from_cp" {
  count             = var.enable_kubelet_10250 ? 1 : 0
  type              = "ingress"
  security_group_id = var.workers_sg_id

  protocol  = "tcp"
  from_port = 10250
  to_port   = 10250

  source_security_group_id = var.control_plane_sg_id
  description              = "${local.desc_prefix}: kubelet HTTPS (TCP/10250) control plane to workers"
}

resource "aws_security_group_rule" "cp_kubelet_10250_self" {
  count             = var.enable_kubelet_10250 ? 1 : 0
  type              = "ingress"
  security_group_id = var.control_plane_sg_id

  protocol  = "tcp"
  from_port = 10250
  to_port   = 10250

  source_security_group_id = var.control_plane_sg_id
  description              = "${local.desc_prefix}: kubelet HTTPS (TCP/10250) within control plane"
}

resource "aws_security_group_rule" "cp_kubelet_10250_from_workers" {
  count             = var.enable_kubelet_10250 ? 1 : 0
  type              = "ingress"
  security_group_id = var.control_plane_sg_id

  protocol  = "tcp"
  from_port = 10250
  to_port   = 10250

  source_security_group_id = var.workers_sg_id
  description              = "${local.desc_prefix}: kubelet HTTPS (TCP/10250) workers to control plane"
}

resource "aws_security_group_rule" "workers_kubelet_10250_from_pods" {
  count             = var.enable_kubelet_10250 && var.pod_cidr != null ? 1 : 0
  type              = "ingress"
  security_group_id = var.workers_sg_id

  protocol  = "tcp"
  from_port = 10250
  to_port   = 10250

  cidr_blocks = [var.pod_cidr]
  description = "${local.desc_prefix}: kubelet HTTPS (TCP/10250) from Pod CIDR"
}

resource "aws_security_group_rule" "cp_kubelet_10250_from_pods" {
  count             = var.enable_kubelet_10250 && var.pod_cidr != null ? 1 : 0
  type              = "ingress"
  security_group_id = var.control_plane_sg_id

  protocol  = "tcp"
  from_port = 10250
  to_port   = 10250

  cidr_blocks = [var.pod_cidr]
  description = "${local.desc_prefix}: kubelet HTTPS (TCP/10250) from Pod CIDR"
}
