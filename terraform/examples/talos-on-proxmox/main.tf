# Step 1: Look up a Talos OS image from the Image Factory.
#
# The module queries the Image Factory to build a schematic for the
# requested extensions and returns the installer image URL plus the ISO
# URL/expected file path - it doesn't download or upload anything itself.
# Before running Step 2 for the first time, tell Proxmox to fetch the ISO
# to each node yourself, via the API's download-url endpoint (see the
# module README):
#
#   curl -k -H "Authorization: PVEAPIToken=<user>@<realm>!<token-id>=<secret>" \
#     -X POST "https://<proxmox-host>:8006/api2/json/nodes/<node>/storage/<datastore>/download-url" \
#     --data-urlencode "content=iso" \
#     --data-urlencode "filename=$(tofu output -raw iso_file_name)" \
#     --data-urlencode "url=$(tofu output -raw iso_url)"
#
# Platform is "nocloud": it's what makes Talos read the static IP we hand
# it below via cloud-init, instead of waiting on DHCP.
module "talos_image" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/talos/images?ref=blog/homelab-diary-part5"

  talos_image_version  = var.talos_version
  talos_image_platform = "nocloud"

  # Add Talos extensions required by the cluster nodes.
  # The full extension catalogue is at https://factory.talos.dev.
  talos_image_extensions = [
    "siderolabs/qemu-guest-agent",
  ]
}

# Step 2: Provision one Proxmox VM per Talos node.
#
# Each VM boots from the image downloaded above (attached as a cdrom); the
# actual disk starts empty and Talos installs itself onto it on first boot.
# The static IP comes from cloud-init, which the nocloud platform picks up
# before Talos even has a machine config to work from.
module "vms" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/virtual-machines?ref=blog/homelab-diary-part5"

  virtual_machines = local.virtual_machines
}

# Step 3: Bootstrap a Talos Kubernetes cluster on top of the VMs above.
#
# Each node's mac_address comes straight from module.vms, not a variable -
# Proxmox assigns the MAC when the VM is created, and Talos just needs to be
# told the same address so it can match the right NIC in its network config.
#
# region reuses the cluster name - the Proxmox CSI plugin wired in below
# needs it for volume topology matching.
module "talos_cluster" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/talos?ref=blog/homelab-diary-part5"

  cluster = {
    name                = var.talos_cluster_name
    region              = var.talos_cluster_name
    gateway_api_version = var.gateway_api_version
    disable_kube_proxy  = true # Cilium (deployed below) replaces kube-proxy with its own eBPF implementation
  }

  nodes = local.talos_nodes
}

# Step 4: Create a Proxmox role, user, and API token scoped to just what the CSI plugin needs.
module "k8s_csi_role" {
  source  = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/users/role?ref=blog/homelab-diary-part5"
  role_id = "hovorkalabs-foundation-talos-k8s-csi"
  privileges = [
    "VM.Audit",
    "VM.Config.Disk",
    "VM.Allocate",
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.Audit"
  ]
}

module "k8s_csi_user" {
  source  = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/users/user?ref=blog/homelab-diary-part5"
  user_id = "hovorkalabs-foundation-talos-k8s-csi-user@pve"

  acls = [
    {
      path      = "/"
      role_id   = module.k8s_csi_role.role_id
      propagate = true
    }
  ]
}

module "k8s_csi_user_token" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/users/user-token?ref=blog/homelab-diary-part5"

  user_id               = module.k8s_csi_user.user_id
  token_name            = "hovorkalabs-foundation-talos-k8s-csi-user-token"
  expiration_date       = "2033-01-01T22:00:00Z"
  privileges_separation = false
}

# Step 5: Deploy the Proxmox CSI plugin, authenticating with the token from Step 4.
module "proxmox_csi_plugin" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/proxmox-csi-plugin?ref=blog/homelab-diary-part5"
  depends_on = [module.prometheus_operator_crds]

  chart_version        = "0.5.12"
  proxmox_url          = "${var.proxmox_endpoint}/api2/json"
  proxmox_insecure     = var.proxmox_insecure
  proxmox_token_id     = module.k8s_csi_user_token.full_token_id
  proxmox_token_secret = module.k8s_csi_user_token.token_value
  proxmox_region       = var.talos_cluster_name

  values_path = [
    "${path.module}/proxmox-csi-values.yaml"
  ]
}

# Step 6: Install the Prometheus Operator CRDs. Cilium's chart (Step 7)
# creates ServiceMonitor resources when its Prometheus integration is
# enabled, so those CRDs need to already exist in the cluster.
module "prometheus_operator_crds" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/prometheus-operator-crds?ref=blog/homelab-diary-part5"
  depends_on = [module.talos_cluster]

  chart_version = "32.0.1"
}

# Step 7: Deploy Cilium as the cluster's CNI, replacing kube-proxy (see
# disable_kube_proxy in Step 3) with its own eBPF-based implementation.
module "cilium" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/cilium?ref=blog/homelab-diary-part5"

  cilium_values_path = [
    "${path.module}/cilium-values.yaml"
  ]

  depends_on = [module.proxmox_csi_plugin]

  chart_version = "1.19.1"
}
