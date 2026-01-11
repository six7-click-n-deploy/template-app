########################################
# CONTRACT-Variablen (PFLICHT)
# Werden vom Worker/Platform gesetzt
########################################

variable "app_name" {
  type        = string
  description = "[CONTRACT] App Name für Image (wird zu: app_name-app_version)"
}

variable "app_version" {
  type        = string
  description = "[CONTRACT] App Version für Image"
}

variable "networks" {
  type        = list(string)
  description = "[CONTRACT] Netzwerk-UUIDs für Build-VM"
}

variable "security_groups" {
  type        = list(string)
  description = "[CONTRACT] Security Groups für Build-VM"
}

variable "floating_ip_pool" {
  type        = string
  description = "[CONTRACT] External Network für Floating IP"
}

########################################
# CUSTOM-Variablen (Optional)
# Werden vom User gesetzt
########################################
