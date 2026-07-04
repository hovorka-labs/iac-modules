variable "proxmox_endpoint" {
  description = "Proxmox API endpoint (e.g., https://pve.example.com:8006)"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the format 'USER@REALM!TOKENID=SECRET'"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for the Proxmox API (useful for self-signed certs)"
  type        = bool
  default     = false
}

variable "talos_version" {
  description = "Talos OS version to deploy (e.g., v1.9.5)"
  type        = string
  default     = "v1.9.5"
}

variable "proxmox_nodes" {
  description = "Proxmox nodes to download the Talos image to; defaults to all nodes in the cluster"
  type        = set(string)
  default     = null
}

variable "proxmox_datastore" {
  description = "Proxmox datastore to store the Talos image"
  type        = string
  default     = "local"
}

variable "nodes" {
  description = "Talos nodes to provision as Proxmox VMs, keyed by node name"
  type = map(object({
    role         = string # "controlplane" or "worker"
    proxmox_node = string
    ip           = string # CIDR, e.g. "192.168.1.10/24"
  }))
}

variable "network_gateway" {
  description = "Gateway address handed to each node via cloud-init"
  type        = string
}

variable "network_dns_servers" {
  description = "DNS servers handed to each node via cloud-init"
  type        = list(string)
  default     = ["1.1.1.1"]
}
