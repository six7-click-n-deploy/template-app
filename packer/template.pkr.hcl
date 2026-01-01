packer {
  required_plugins {
    openstack = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/openstack"
    }
  }
}

variable "image_name" {
  type        = string
  default     = "template-image"
  description = "Name of the image to build"
}

variable "source_image" {
  type        = string
  default     = "Ubuntu 22.04"
  description = "Base image to build from"
}

variable "flavor" {
  type        = string
  default     = "gp1.small"
  description = "Instance size for build VM (same as deployment)"
}

variable "networks" {
  type        = list(string)
  description = "Network IDs or names for build VM"
  default     = ["4971e080-966d-485e-a161-3e2b7fefad53"]
}

variable "floating_ip_pool" {
  type        = string
  default     = "DHBW"
  description = "External network for floating IP"
}

variable "security_group" {
  type        = string
  default     = "simple-webserver-sg-ff3ad318"
  description = "Security group with SSH/HTTP/HTTPS access"
}

source "openstack" "template" {
  image_name        = var.image_name
  source_image_name = var.source_image
  flavor            = var.flavor
  networks          = var.networks

  use_blockstorage_volume = true
  volume_size             = 10

  use_floating_ip = false

  ssh_ip_version = "4"
  ssh_timeout    = "15m"
  ssh_username   = "ubuntu"

  security_groups = [var.security_group]
}

build {
  sources = ["source.openstack.template"]

  provisioner "shell" {
    script = "scripts/provision.sh"
  }
}

