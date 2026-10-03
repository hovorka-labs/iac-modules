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
  description = "Talos OS version to deploy (e.g., v1.14.2) - must be >= v1.12, since the talos module always patches a HostnameConfig document that older versions don't recognize, and must be >= v1.14 since the pinned talos provider (~> 0.12) generates a DiscoveryServiceConfig document that older Talos versions can't parse"
  type        = string
  default     = "v1.14.2"
}

variable "datastore" {
  description = "Proxmox datastores to use - iso needs ISO image content enabled, disk needs disk image content enabled (these are often different storages, e.g. a directory-backed 'local' for ISOs vs. an LVM-thin 'local-lvm' for disks)"
  type = object({
    iso  = string
    disk = string
  })
  default = {
    iso  = "local"
    disk = "local-lvm"
  }
}

variable "nodes" {
  description = "Talos nodes to provision as Proxmox VMs, keyed by node name"
  type = map(object({
    # "controlplane" or "worker"
    role         = string
    proxmox_node = string
    # CIDR, e.g. "192.168.1.10/24"
    ip = string
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

variable "talos_cluster_name" {
  description = "Talos cluster name"
  type        = string
  default     = "talos-on-proxmox"
}

variable "k8s_version" {
  description = "Kubernetes version to deploy (e.g., v1.32.3) - must be >= v1.32.0 and < v1.38.0, the range Talos 1.14 supports"
  type        = string
  default     = "v1.32.3"
}

variable "gateway_api_version" {
  description = "Gateway API version whose CRDs get installed at cluster bootstrap"
  type        = string
  default     = "v1.2.1"
}
