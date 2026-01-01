output "instance_id" {
  value = openstack_compute_instance_v2.app.id
}

output "floating_ip" {
  value = openstack_networking_floatingip_v2.app_fip.address
}

output "access_url" {
  value = "http://${openstack_networking_floatingip_v2.app_fip.address}"
}

output "security_group_id" {
  value = openstack_networking_secgroup_v2.app_sg.id
}
