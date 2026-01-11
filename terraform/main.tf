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
  cloud = "openstack"
}

############################
# DATA SOURCES
############################

data "openstack_images_image_v2" "image" {
  name        = var.image_name
  most_recent = true
}

data "openstack_networking_network_v2" "external" {
  count = var.floating_ip_pool != null ? 1 : 0
  name  = var.floating_ip_pool
}

############################
# NETWORKING
############################

resource "openstack_networking_secgroup_v2" "app_sg" {
  name        = "app-sg"
  description = "Security group for app"
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

resource "openstack_networking_floatingip_v2" "fip" {
  count = var.floating_ip_pool != null ? 1 : 0
  pool  = data.openstack_networking_network_v2.external[0].name
}

############################
# USER MANAGEMENT
############################

# Flatten users from teams
locals {
  all_users = flatten([
    for team, members in var.users : [
      for member in members : {
        id       = "${team}-${replace(split("@", member.email)[0], ".", "-")}"
        team     = team
        email    = member.email
        username = replace(split("@", member.email)[0], ".", "-")
      }
    ]
  ])
  
  users_map = { for user in local.all_users : user.id => user }
  teams_list = distinct([for user in local.all_users : user.team])
}

# Passwörter für jeden User generieren
resource "random_password" "user_passwords" {
  for_each = local.users_map
  length   = 16
  special  = true
}

############################
# COMPUTE
############################

resource "openstack_compute_instance_v2" "app" {
  name            = "app-instance"
  image_id        = data.openstack_images_image_v2.image.id
  flavor_name     = "gp1.small"
  key_pair        = var.key_pair
  security_groups = [openstack_networking_secgroup_v2.app_sg.name]

  network {
    uuid = var.network_uuid
  }

  # User-Accounts per cloud-init erstellen
  user_data = templatefile("${path.module}/user-data.yaml.tpl", {
    users = local.users_map
    teams = local.teams_list
    passwords = { for id, pwd in random_password.user_passwords : id => pwd.result }
  })
}

resource "openstack_compute_floatingip_associate_v2" "fip_assoc" {
  count       = var.floating_ip_pool != null ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.fip[0].address
  instance_id = openstack_compute_instance_v2.app.id
}

############################
# [CONTRACT] User Accounts Output
############################

locals {
  user_accounts = {
    for user_id, user in local.users_map : user_id => {
      type     = "password"
      ip       = var.floating_ip_pool != null ? openstack_networking_floatingip_v2.fip[0].address : openstack_compute_instance_v2.app.network[0].fixed_ip_v4
      port     = 22
      username = user.username
      auth     = random_password.user_passwords[user_id].result
    }
  }
}
