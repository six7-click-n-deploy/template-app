############################
# User Accounts Output
############################

# Schema user_accounts:
# "<team>-<username>": {
#   type     = "password"   # password | ssh_key | oauth | none
#   ip       = "1.2.3.4"
#   port     = 80
#   username = "alice@example.com"
#   auth     = "<passwort>"
# }

output "user_accounts" {
  description = "User accounts mit Zugangsdaten fuer jeden User"
  value       = local.user_accounts
  sensitive   = true
}

############################
# Team-VM Details
############################

output "team_vms" {
  description = "Details aller Team-VMs"
  value = {
    for team in local.teams_list : team => {
      instance_id   = openstack_compute_instance_v2.team_vm[team].id
      instance_name = openstack_compute_instance_v2.team_vm[team].name
      fixed_ip      = openstack_networking_port_v2.team_port[team].all_fixed_ips[0]
      floating_ip   = local.enable_floating_ip ? openstack_networking_floatingip_v2.team_fip[team].address : null
      # TODO: URL-Pfad auf App anpassen (z.B. "/pgadmin4", "/" etc.)
      url = local.enable_floating_ip ? "http://${openstack_networking_floatingip_v2.team_fip[team].address}" : "http://${openstack_networking_port_v2.team_port[team].all_fixed_ips[0]}"
    }
  }
}

output "teams_summary" {
  description = "Uebersicht: Teams und User-Anzahl"
  value = {
    for team in local.teams_list : team => length([for uid, u in local.users_map : u if u.team == team])
  }
}
