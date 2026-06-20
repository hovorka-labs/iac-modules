terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.86.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.10.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38.0"
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
