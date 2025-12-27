terraform {
  required_version = ">= 1.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "openstack" {
  # Credentials come from OS_* environment variables / clouds.yaml
}

data "openstack_images_image_v2" "app_image" {
  name        = var.image_name
  most_recent = true
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "openstack_networking_secgroup_v2" "app_sg" {
  name        = "${var.instance_name}-sg-${random_id.suffix.hex}"
  description = "Security group for Deploy-O-Matic web app"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.app_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.app_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.app_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.app_sg.id
}

data "openstack_networking_network_v2" "external" {
  name = var.floating_ip_pool
}

resource "openstack_compute_instance_v2" "app" {
  name        = var.instance_name
  image_name  = data.openstack_images_image_v2.app_image.name
  flavor_name = var.flavor
  key_pair    = var.key_pair

  security_groups = [openstack_networking_secgroup_v2.app_sg.name]

  network {
    uuid = var.network_uuid
  }

  metadata = {
    deployed_by = "click-n-deploy-worker"
    app         = "deploy-o-matic"
    environment = var.environment
  }
}

resource "openstack_networking_floatingip_v2" "app_fip" {
  pool = data.openstack_networking_network_v2.external.name
}

resource "openstack_compute_floatingip_associate_v2" "app_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.app_fip.address
  instance_id = openstack_compute_instance_v2.app.id

  depends_on = [openstack_compute_instance_v2.app]
}
