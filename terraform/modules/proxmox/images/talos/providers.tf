terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.110.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.11.0"
    }
  }
}
