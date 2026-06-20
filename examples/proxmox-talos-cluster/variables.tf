variable "proxmox_endpoint" {
  description = "Proxmox API URL (e.g. https://pve.example.com:8006)"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token (e.g. user@pve!token=secret)"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for the Proxmox API"
  type        = bool
  default     = false
}
