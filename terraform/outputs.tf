output "instance_id" {
  description = "ID of the created instance"
  value       = openstack_compute_instance_v2.app.id
}

output "instance_name" {
  description = "Name of the created instance"
  value       = openstack_compute_instance_v2.app.name
}

output "instance_private_ip" {
  description = "Private IP address of the instance"
  value       = try(openstack_compute_instance_v2.app.network[0].fixed_ip_v4, null)
}

output "floating_ip" {
  description = "Public floating IP address"
  value       = openstack_networking_floatingip_v2.app_fip.address
}

output "security_group_id" {
  description = "ID of the created security group"
  value       = openstack_networking_secgroup_v2.app_sg.id
}

output "access_url" {
  description = "URL to access the app"
  value       = "http://${openstack_networking_floatingip_v2.app_fip.address}"
}
