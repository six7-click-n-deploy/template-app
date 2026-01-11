############################
# [CONTRACT] User Accounts Output
# App-Entwickler MUSS local.user_accounts in main.tf befüllen!
############################

# CONTRACT-SCHEMA:
# local.user_accounts = {
#   "<team>-<username>": {
#     type     = "ssh" | "password" | "api-token" | ...
#     ip       = "1.2.3.4"              # string
#     port     = 22 | 3306 | 443 | ...  # number
#     username = "john-doe"             # string
#     auth     = "key/pwd/token"        # string (Wert, nicht Pfad!)
#   }
# }

output "user_accounts" {
  description = "[CONTRACT] User accounts - Struktur siehe Kommentar oben"
  value       = local.user_accounts
}

############################
# [CUSTOM] Instance Outputs
############################

output "instance_id" {
  value       = openstack_compute_instance_v2.app.id
  description = "OpenStack Instance ID"
}

output "instance_ip" {
  value       = var.floating_ip_pool != null ? openstack_networking_floatingip_v2.fip[0].address : openstack_compute_instance_v2.app.network[0].fixed_ip_v4
  description = "Public IP address (oder interne IP wenn keine Floating IP)"
}