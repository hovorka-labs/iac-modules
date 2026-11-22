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
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/talos/images?ref=blog/homelab-diary-part7"

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
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/virtual-machines?ref=blog/homelab-diary-part7"

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
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/talos?ref=blog/homelab-diary-part7"

  cluster = {
    name               = var.talos_cluster_name
    region             = var.talos_cluster_name
    extra_manifests    = local.gateway_api_manifests
    disable_kube_proxy = true # Cilium (deployed below) replaces kube-proxy with its own eBPF implementation

    # Talos's root filesystem is read-only, so local-path-provisioner's
    # default host path (needed by OpenBao's PVC, Step 7 below) doesn't
    # exist and can't be written to. This bind-mounts a subdirectory of
    # Talos's already-writable /var partition into the kubelet itself - see
    # vendor/local-path-provisioner-v0.0.31.yaml for the other half of this.
    kubelet_extra_mounts = [{
      destination = "/var/local-path-provisioner"
      source      = "/var/local-path-provisioner"
    }]
  }

  nodes = local.talos_nodes
}

# Step 4: Install the Prometheus Operator CRDs. Cilium's chart (Step 5)
# creates ServiceMonitor resources when its Prometheus integration is
# enabled, so those CRDs need to already exist in the cluster.
module "prometheus_operator_crds" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/prometheus-operator-crds?ref=blog/homelab-diary-part7"
  depends_on = [module.talos_cluster]

  chart_version = "32.0.1"
}

# Step 5: Deploy Cilium as the cluster's CNI, replacing kube-proxy (see
# disable_kube_proxy in Step 3) with its own eBPF-based implementation.
module "cilium" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/cilium?ref=blog/homelab-diary-part7"

  cilium_values_path = [
    "${path.module}/cilium-values.yaml"
  ]

  depends_on = [module.prometheus_operator_crds]

  chart_version = "1.19.1"
}

# Step 6: Deploy local-path-provisioner, so something can satisfy OpenBao's
# PVC (Step 7) without reviving the Proxmox CSI plugin's spot in this
# critical path - CSI is still deliberately deferred to ArgoCD, and nothing
# about that has changed. No official Helm chart exists for
# local-path-provisioner, so this applies its vendored manifest as-is via
# the raw-manifests escape hatch instead.
module "local_path_provisioner" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/raw-manifests?ref=blog/homelab-diary-part7"
  depends_on = [module.cilium]

  release_name = "local-path-provisioner"
  namespace    = "local-path-storage"

  manifests = [
    file("${path.module}/vendor/local-path-provisioner-v0.0.31.yaml")
  ]
}

# Step 7: Deploy OpenBao - the secrets store everything from here on reads
# from. It boots sealed and does nothing useful until
# scripts/openbao.sh init/unseal/configure has been run once; that's a
# manual follow-up step, not a second apply (see the module's README for
# why this release doesn't wait on rollout).
module "openbao" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/openbao?ref=blog/homelab-diary-part7"
  depends_on = [module.local_path_provisioner]

  chart_version = "0.30.7"

  values_path = [
    "${path.module}/openbao-values.yaml"
  ]
}

# Step 8: Deploy External Secrets Operator - turns "a secret lives in
# OpenBao" into a real Kubernetes Secret. Only depends on Cilium, not
# OpenBao/local-path-provisioner: ESO itself needs nothing but a working
# CNI to install, so this is free to run in parallel with Steps 6-7.
module "external_secrets" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/external-secrets?ref=blog/homelab-diary-part7"
  depends_on = [module.cilium]

  chart_version = "2.15.0"

  values_path = [
    "${path.module}/external-secrets-values.yaml"
  ]
}

# Step 9: Apply the ClusterSecretStore pointed at OpenBao, plus one demo
# ExternalSecret - both as raw manifests, deliberately NOT via the
# external-secrets chart's own `extraObjects` values, to avoid racing its
# CRDs/webhook registration within a single helm install. Depending on
# external_secrets is load-bearing (its CRDs must already be registered);
# depending on openbao is not (nothing here checks live connectivity at
# apply time) - it's just accurate to say this CR's spec references it.
module "eso_config" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/raw-manifests?ref=blog/homelab-diary-part7"
  depends_on = [module.external_secrets, module.openbao]

  release_name = "eso-config"
  namespace    = "default"

  manifests = [
    file("${path.module}/eso-cluster-secret-store.yaml"),
    file("${path.module}/eso-demo-externalsecret.yaml")
  ]
}

# Step 10: Deploy ArgoCD. From here on, this module's job is done - ArgoCD
# takes over reconciling everything else straight from Git. Values go
# straight to the upstream argo-cd chart (no wrapper chart involved), so
# keys like `server`/`configs`/`redis` sit at the top level, not nested
# under an `argo-cd:` key.
#
# Deliberately still only depends_on cilium - NOT eso_config/openbao. A
# real deployment's ArgoCD gets its private-repo credentials from a Secret
# that ESO materializes from OpenBao, but ArgoCD discovers that Secret by
# label at any time, asynchronously, independent of Tofu - there's no real
# dependency edge here even though those steps now sit earlier in this file.
module "argocd" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/argocd?ref=blog/homelab-diary-part7"
  depends_on = [module.cilium]

  chart_version = "9.5.19"

  values_path = [
    "${path.module}/argocd-values.yaml"
  ]
}

# Step 11: Bootstrap ArgoCD's root Application - an "app of apps" pointing at
# a Git repo. This is the last resource OpenTofu ever creates inside the
# cluster: everything from here on is reconciled by ArgoCD itself, straight
# from Git.
module "argocd_apps" {
  source     = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/helm/argocd-apps?ref=blog/homelab-diary-part7"
  depends_on = [module.argocd]

  chart_version = "2.0.7"

  values_path = [
    "${path.module}/argocd-apps-values.yaml"
  ]
}
