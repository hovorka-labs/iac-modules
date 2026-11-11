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
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/talos/images?ref=blog/homelab-diary-part6"

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
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/virtual-machines?ref=blog/homelab-diary-part6"

  virtual_machines = local.virtual_machines
}

# Step 3: Bootstrap a Talos Kubernetes cluster on top of the VMs above.
#
# Each node's mac_address comes straight from module.vms, not a variable -
# Proxmox assigns the MAC when the VM is created, and Talos just needs to be
# told the same address so it can match the right NIC in its network config.
#
# region reuses the cluster name - the Proxmox CSI plugin (deployed later,
# via ArgoCD) needs it for volume topology matching.
module "talos_cluster" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/talos?ref=blog/homelab-diary-part6"

  cluster = {
    name                = var.talos_cluster_name
    region              = var.talos_cluster_name
    gateway_api_version = var.gateway_api_version
    disable_kube_proxy  = true # Cilium (deployed below) replaces kube-proxy with its own eBPF implementation
  }

  nodes = local.talos_nodes
}

# Step 4: Install the Prometheus Operator CRDs. Cilium's chart (Step 5)
# creates ServiceMonitor resources when its Prometheus integration is
# enabled, so those CRDs need to already exist in the cluster.
module "prometheus_operator_crds" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/prometheus-operator-crds?ref=blog/homelab-diary-part6"
  depends_on = [module.talos_cluster]

  chart_version = "32.0.1"
}

# Step 5: Deploy Cilium as the cluster's CNI, replacing kube-proxy (see
# disable_kube_proxy in Step 3) with its own eBPF-based implementation.
module "cilium" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/cilium?ref=blog/homelab-diary-part6"

  cilium_values_path = [
    "${path.module}/cilium-values.yaml"
  ]

  depends_on = [module.prometheus_operator_crds]

  chart_version = "1.19.1"
}

# Step 6: Deploy ArgoCD. From here on, this module's job is done - ArgoCD
# takes over reconciling everything else straight from Git. Values go
# straight to the upstream argo-cd chart (no wrapper chart involved), so
# keys like `server`/`configs`/`redis` sit at the top level, not nested
# under an `argo-cd:` key.
module "argocd" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/argocd?ref=blog/homelab-diary-part6"
  depends_on = [module.cilium]

  chart_version = "9.5.19"

  values_path = [
    "${path.module}/argocd-values.yaml"
  ]
}

# Step 7: Bootstrap ArgoCD's root Application - an "app of apps" pointing at
# a Git repo. This is the last resource OpenTofu ever creates inside the
# cluster: everything from here on is reconciled by ArgoCD itself, straight
# from Git.
module "argocd_apps" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/argocd-apps?ref=blog/homelab-diary-part6"
  depends_on = [module.argocd]

  chart_version = "2.0.7"

  values_path = [
    "${path.module}/argocd-apps-values.yaml"
  ]
}
