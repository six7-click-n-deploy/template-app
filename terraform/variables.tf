variable "instance_name" {
  type        = string
  description = "Name of the instance"
}

variable "image_name" {
  type        = string
  description = "Name of the Packer-built image to deploy"
}

variable "flavor" {
  type        = string
  description = "OpenStack flavor"
}

variable "key_pair" {
  type        = string
  description = "OpenStack keypair name (required for SSH)"
}

variable "network_uuid" {
  type        = string
  description = "Internal network UUID for the VM"
}

variable "enable_floating_ip" {
  type        = bool
  default     = true
  description = "Whether to allocate + associate a floating IP"
}

variable "floating_ip_pool" {
  type        = string
  default     = ""
  description = "External network/pool name used for floating IPs (required if enable_floating_ip=true)"
}

variable "ssh_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR allowed to SSH (recommend: your.ip/32)"
}

variable "allowed_tcp_ports" {
  type        = list(number)
  default     = []
  description = "Public TCP ports to allow (e.g. [80, 443]). Empty means: only SSH (plus optional ICMP)."
}

variable "allow_icmp" {
  type        = bool
  default     = true
  description = "Allow ping (ICMP)"
}

variable "metadata" {
  type        = map(string)
  default     = {}
  description = "Metadata applied to the instance"
}
