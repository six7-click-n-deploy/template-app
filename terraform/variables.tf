variable "instance_name" {
  type        = string
  default     = "my-app"
  description = "Name of the instance"
}

variable "image_name" {
  type    = string
  default = "template-image"
}

variable "flavor" {
  type        = string
  default     = "gp1.small"
  description = "OpenStack flavor"
}

variable "key_pair" {
  type        = string
  default     = ""
  description = "OpenStack keypair name (required for SSH)"
}

variable "network_uuid" {
  type        = string
  default     = "4971e080-966d-485e-a161-3e2b7fefad53"
  description = "Internal network UUID for the VM"
}

variable "floating_ip_pool" {
  type        = string
  default     = "DHBW"
  description = "External network name/pool used for Floating IPs"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment tag"
}

variable "ssh_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR allowed to SSH (set to your.ip/32 for safety)"
}
