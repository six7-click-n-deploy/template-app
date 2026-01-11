########################################
# CONTRACT-Variablen (PFLICHT)
# Müssen vom Worker/Platform-Team gesetzt werden
########################################

variable "image_name" {
  type        = string
  description = "[CONTRACT] Name des Packer-Images (app_name-app_version)"
}

variable "users" {
  description = "[CONTRACT] Teams mit User-Emails"
  type = map(list(object({
    email = string
  })))
  default = {}
}

variable "network_uuid" {
  type        = string
  description = "[CONTRACT] UUID des internen Netzwerks"
}

variable "key_pair" {
  type        = string
  description = "[OPTIONAL] OpenStack SSH Key Pair Name (null wenn keine SSH-Keys)"
  default     = null
}

variable "floating_ip_pool" {
  type        = string
  description = "[OPTIONAL] External Network für Floating IPs (null für nur-intern)"
  default     = null
}