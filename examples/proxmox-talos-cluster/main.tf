# Proxmox CSI Role — grants storage-related permissions for the Kubernetes CSI driver
module "k8s_csi_role" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/users/role?ref=v0.6.0"

  role_id = "${local.cluster_name}-k8s-csi"
  privileges = [
    "VM.Audit",
    "VM.Config.Disk",
    "VM.Allocate",
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.Audit",
  ]
}

# Proxmox CSI User — dedicated service account for the CSI driver
module "k8s_csi_user" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/users/user?ref=v0.6.0"

  user_id = "${local.cluster_name}-k8s-csi-user@pve"
  acls = [
    {
      path      = "/"
      role_id   = module.k8s_csi_role.role_id
      propagate = true
    },
  ]
}

# Proxmox CSI API Token — used by the CSI driver to authenticate against the Proxmox API
module "k8s_csi_user_token" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/users/user-token?ref=v0.6.0"

  user_id               = module.k8s_csi_user.user_id
  token_name            = "${local.cluster_name}-k8s-csi-token"
  expiration_date       = "2033-01-01T22:00:00Z"
  privileges_separation = false
}

# Talos Image — downloads the Talos ISO with extensions to each Proxmox node
module "talos_image" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/images/talos?ref=v0.6.0"

  proxmox_nodes     = local.proxmox_nodes
  proxmox_datastore = local.proxmox_datastore_iso

  talos_version = local.talos_version
  extensions    = local.talos_extensions
  platform      = "nocloud"
}

# Proxmox VMs — creates the virtual machines that will become Talos nodes
module "vms" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/virtual-machines?ref=v0.6.0"
  depends_on = [module.talos_image]

  vms = local.proxmox_vms
}

# Talos Cluster — bootstraps the Kubernetes cluster on the VMs
module "talos_cluster" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/talos?ref=v0.6.0"
  depends_on = [module.vms]

  nodes = local.talos_nodes
  cluster_config = {
    talos_cluster_name    = local.cluster_name
    cluster_name          = local.proxmox_cluster_name
    gateway_api_version   = local.gateway_api_version
    vip                   = local.network.vip
    pod_subnets           = local.network.pod_subnets
    service_subnets       = local.network.service_subnets
    disable_kube_proxy    = true
    api_server_extra_sans = ["kubeapi.${local.cluster_name}.example.com"]
  }
}

# Prometheus Operator CRDs — installed before any ServiceMonitor-aware charts
module "prometheus_operator_crds" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/prometheus-operator-crds?ref=v0.6.0"
  depends_on = [module.talos_cluster]

  chart_version = "26.0.0"
}

# Proxmox CSI Plugin — enables Proxmox storage volumes in Kubernetes
module "proxmox_csi_plugin" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/proxmox-csi-plugin?ref=v0.6.0"
  depends_on = [module.prometheus_operator_crds]

  chart_version        = "0.5.5"
  proxmox_url          = "${var.proxmox_endpoint}/api2/json"
  proxmox_insecure     = var.proxmox_insecure
  proxmox_token_id     = module.k8s_csi_user_token.full_token_id
  proxmox_token_secret = module.k8s_csi_user_token.token_value
  proxmox_region       = local.proxmox_cluster_name

  values_path = ["${path.module}/proxmox-csi-values.yaml"]
}

# Cilium — CNI plugin replacing kube-proxy
module "cilium" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/cilium?ref=v0.6.0"
  depends_on = [module.proxmox_csi_plugin]

  chart_version      = "1.19.1"
  cilium_values_path = ["${path.module}/cilium-values.yaml"]
}
