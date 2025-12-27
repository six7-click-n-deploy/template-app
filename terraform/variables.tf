variable "instance_name" {
  description = "Name of the instance"
  type        = string
  default     = "deploy-o-matic"
}

variable "image_name" {
  description = "Name of the image to use (Packer-built with nginx + app page)"
  type        = string
  default     = "deploy-o-matic-image"
}

variable "flavor" {
  description = "Flavor (instance type) to use"
  type        = string
  default     = "gp1.small"
}

variable "key_pair" {
  description = "SSH key pair name"
  type        = string
  default     = ""
}

variable "network_uuid" {
  description = "UUID of the internal network to attach the instance to"
  type        = string
  default     = "34a00b87-57ce-42c4-8e1b-9ea8a657ec2e"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "development"
}

variable "floating_ip_pool" {
  description = "Name of the floating IP pool (external network)"
  type        = string
  default     = "DHBW"
}
