terraform {
  required_version = ">= 1.12"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.11"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
}

provider "talos" {}

provider "helm" {
  kubernetes = {
    host                   = local.kubeconfig_data.host
    cluster_ca_certificate = local.kubeconfig_data.cluster_ca_certificate
    client_certificate     = local.kubeconfig_data.client_certificate
    client_key             = local.kubeconfig_data.client_key
  }
}

provider "kubernetes" {
  host                   = local.kubeconfig_data.host
  cluster_ca_certificate = local.kubeconfig_data.cluster_ca_certificate
  client_certificate     = local.kubeconfig_data.client_certificate
  client_key             = local.kubeconfig_data.client_key
}
