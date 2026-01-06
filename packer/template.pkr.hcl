packer {
  required_plugins {
    openstack = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/openstack"
    }
  }
}

# -----------------------------------------------------------------------------
# TEMPLATE: Diese Variablen werden pro Umgebung/Projekt gesetzt (pkrvars.hcl / CI).
# Keine Hardcodings (Netz, SG, Pools etc.).
# -----------------------------------------------------------------------------

variable "image_name" {
  type        = string
  description = "Name of the image to build (output image name)"
}

variable "source_image_name" {
  type        = string
  description = "Base image name in OpenStack (input image name)"
}

variable "flavor" {
  type        = string
  description = "Flavor used for the temporary build VM"
}

variable "networks" {
  type        = list(string)
  description = "Network IDs or names attached to the build VM"
}

variable "security_groups" {
  type        = list(string)
  default     = []
  description = "Security groups for build VM (must allow SSH from your runner/bastion)"
}

variable "ssh_username" {
  type        = string
  default     = "ubuntu"
  description = "SSH user present in the base image"
}

variable "ssh_timeout" {
  type        = string
  default     = "15m"
  description = "How long to wait for SSH"
}

variable "use_blockstorage_volume" {
  type        = bool
  default     = true
  description = "Use Cinder volume for build (common on OpenStack)"
}

variable "volume_size" {
  type        = number
  default     = 10
  description = "Volume size in GB (only used if blockstorage volume is enabled)"
}

# Optional – nur falls dein Build-VM sonst nicht erreichbar ist
variable "use_floating_ip" {
  type        = bool
  default     = false
  description = "Attach a floating IP to the build VM (only if needed)"
}

variable "floating_ip_pool" {
  type        = string
  default     = ""
  description = "External network/pool name for floating IP (only used if use_floating_ip=true)"
}

# Provisioning-Einstiegspunkt: in Templates bewusst als Variable
variable "provision_script" {
  type        = string
  default     = "scripts/provision.sh"
  description = "Shell script executed inside the build VM (put your app setup there)"
}

source "openstack" "image" {
  image_name        = var.image_name
  source_image_name = var.source_image_name
  flavor            = var.flavor
  networks          = var.networks

  security_groups = var.security_groups

  use_blockstorage_volume = var.use_blockstorage_volume
  volume_size             = var.volume_size

  use_floating_ip  = var.use_floating_ip
  floating_ip_pool = var.floating_ip_pool != "" ? var.floating_ip_pool : null

  ssh_ip_version = "4"
  ssh_timeout    = var.ssh_timeout
  ssh_username   = var.ssh_username
}


# Richtige App Anpassungen gekapselt in provision.sh machen!

build {
  sources = ["source.openstack.image"]

  provisioner "shell" {
    script = var.provision_script
  }
}
