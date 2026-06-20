variable "chart_version" {
  description = "proxmox-csi-plugin chart version"
  type        = string
}

variable "values_path" {
  description = "List of values file paths"
  type        = list(string)
  default     = []
}

variable "proxmox_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for Proxmox API"
  type        = bool
  default     = false
}

variable "proxmox_token_id" {
  description = "Proxmox API token ID (user@realm!token_name)"
  type        = string
  sensitive   = true
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_region" {
  description = "Proxmox region (cluster name)"
  type        = string
}
