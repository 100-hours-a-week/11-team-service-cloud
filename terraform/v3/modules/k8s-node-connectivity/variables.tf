variable "name_prefix" {
  description = "Prefix for rule descriptions/names"
  type        = string
}

variable "control_plane_sg_id" {
  description = "Security group id for control plane nodes"
  type        = string
}

variable "workers_sg_id" {
  description = "Security group id for worker nodes"
  type        = string
}

variable "pod_cidr" {
  description = "Pod CIDR supernet (e.g. 192.168.0.0/16)"
  type        = string
  default     = null
}

variable "enable_calico_bgp" {
  description = "Allow TCP/179 node-to-node (Calico BGP)"
  type        = bool
  default     = true
}

variable "enable_ipip" {
  description = "Allow IP-in-IP (IP protocol 4) node-to-node"
  type        = bool
  default     = true
}

variable "enable_kubelet_10250" {
  description = "Allow kubelet HTTPS (TCP/10250) for metrics/logs"
  type        = bool
  default     = true
}
