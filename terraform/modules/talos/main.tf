# Find the first control plane node IP for bootstrapping and endpoint configuration
locals {
  first_control_plane_node_ip  = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"][0]
  first_control_plane_node_key = [for k, v in var.nodes : k if v.machine_type == "controlplane"][0]

  # Resolve the cluster endpoint: explicit override > VIP > first control plane IP
  kubernetes_endpoint = coalesce(
    var.cluster_config.cluster_endpoint,
    var.cluster_config.vip,
    local.first_control_plane_node_ip
  )

  # Resolve Talos API IPs — used for all direct talosctl/provider communication.
  # When nodes have separate public IPs (e.g. Hetzner), set talos_api_ip to the public IP
  # while ip holds the private cluster IP.
  resolved_talos_api_ips = {
    for name, node in var.nodes : name => (
      node.talos_api_ip != null ? node.talos_api_ip : node.ip
    )
  }

  # First control plane API IP (for bootstrap and kubeconfig retrieval)
  first_control_plane_api_ip = [
    for k, v in var.nodes : local.resolved_talos_api_ips[k]
    if v.machine_type == "controlplane"
  ][0]

  # Extra kubelet arguments per node: cloud-provider ID matching (e.g. Hetzner CCM) and/or
  # taints to self-register with. NodeRestriction forbids a kubelet from modifying its own
  # node's taints after registration (machine.nodeTaints patches get rejected with "is not
  # allowed to modify taints"), but DOES allow taints supplied at initial registration via
  # --register-with-taints — so that's the only mechanism that reliably works for workers.
  kubelet_extra_args = {
    for name, node in var.nodes : name => merge(
      node.provider_id != null ? { "provider-id" = node.provider_id } : {},
      length(node.node_taints) > 0 ? {
        "register-with-taints" = join(",", [for key, value in node.node_taints : "${key}=${value}"])
      } : {}
    )
  }

  # Combine user-provided manifests with required Gateway API resources
  extra_manifests = concat(var.cluster_config.extra_manifests, [
    "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.cluster_config.gateway_api_version}/standard-install.yaml",
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${var.cluster_config.gateway_api_version}/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml"
  ])

  # Prepare config patches for Talos machine config
  node_config_patches = {
    for name, node in var.nodes : name => concat(
      [
        # Common configuration for all nodes
        templatefile("${path.module}/templates/machine-config/common.yaml.tftpl", {
          node_name           = node.node_name
          disable_kube_proxy  = var.cluster_config.disable_kube_proxy
          cluster_name        = var.cluster_config.cluster_name
          k8s_version         = node.k8s_version
          installer_image_url = node.installer_image_url
          machine_type        = node.machine_type
          node_labels         = node.node_labels
        })
      ],
      # Control plane or worker specific configuration
      # Inject kubelet extra args when needed (provider-id for CCM matching, and/or
      # register-with-taints for dedicated worker pools — see kubelet_extra_args above)
      length(local.kubelet_extra_args[name]) > 0 ? [
        yamlencode({
          machine = {
            kubelet = {
              extraArgs = local.kubelet_extra_args[name]
            }
          }
        })
      ] : [],
      node.machine_type == "controlplane" ? [
        templatefile("${path.module}/templates/machine-config/control-plane.yaml.tftpl", {
          extra_manifests                = jsonencode(local.extra_manifests)
          api_server                     = var.cluster_config.api_server
          api_server_extra_sans          = var.cluster_config.api_server_extra_sans
          vip                            = var.cluster_config.vip
          ip                             = node.ip
          pod_subnets                    = var.cluster_config.pod_subnets
          service_subnets                = var.cluster_config.service_subnets
          mac_address                    = lower(node.mac_address)
          interface_name                 = node.interface_name
          use_dhcp                       = node.use_dhcp
          gateway                        = node.gateway
          subnet_mask                    = node.subnet_mask
          allowSchedulingOnControlPlanes = var.cluster_config.allowSchedulingOnControlPlanes
          external_cloud_provider        = var.cluster_config.external_cloud_provider
        })
        ] : [
        templatefile("${path.module}/templates/machine-config/worker.yaml.tftpl", {
          ip             = node.ip
          mac_address    = lower(node.mac_address)
          interface_name = node.interface_name
          use_dhcp       = node.use_dhcp
          gateway        = node.gateway
          subnet_mask    = node.subnet_mask
          api_server     = var.cluster_config.api_server
        })
      ]
    )
  }
}

# Track VM changes that should trigger Talos reconfiguration
resource "terraform_data" "vm_trigger" {
  for_each = var.nodes

  input = {
    # If the VM disk configuration changes,
    # we have to reapply Talos configuration
    hash = try(each.value.recreation_hash)
  }
}

# Generate cluster secrets that will be shared across all nodes
resource "talos_machine_secrets" "this" {}

# Configure the Talos client for cluster management
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_config.talos_cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for k, v in var.nodes : local.resolved_talos_api_ips[k]]
  endpoints            = [for k, v in var.nodes : local.resolved_talos_api_ips[k] if v.machine_type == "controlplane"]
}

# Generate machine configurations for each node
data "talos_machine_configuration" "this" {
  for_each = var.nodes

  cluster_name     = var.cluster_config.talos_cluster_name
  cluster_endpoint = "https://${local.kubernetes_endpoint}:6443"
  machine_type     = each.value.machine_type
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  # Apply configuration templates as patches
  config_patches = local.node_config_patches[each.key]
}

# Apply the machine configurations to each node
resource "talos_machine_configuration_apply" "this" {
  for_each = var.nodes

  node                        = local.resolved_talos_api_ips[each.key]
  apply_mode                  = each.value.apply_mode
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration

  lifecycle {
    replace_triggered_by = [terraform_data.vm_trigger[each.key]]
  }
}

# Re-bootstrap when the first control plane node's VM is recreated
resource "terraform_data" "bootstrap_trigger" {
  input = terraform_data.vm_trigger[local.first_control_plane_node_key].output
}

# Bootstrap the Kubernetes cluster on the first control plane node
resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.this]

  node                 = local.first_control_plane_api_ip
  client_configuration = talos_machine_secrets.this.client_configuration

  lifecycle {
    replace_triggered_by = [terraform_data.bootstrap_trigger]
  }
}

# Verify cluster health after bootstrapping
data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this
  ]

  skip_kubernetes_checks = true
  client_configuration   = data.talos_client_configuration.this.client_configuration

  # Node lists by role for health checks
  control_plane_nodes = [for k, v in var.nodes : local.resolved_talos_api_ips[k] if v.machine_type == "controlplane"]
  worker_nodes        = [for k, v in var.nodes : local.resolved_talos_api_ips[k] if v.machine_type == "worker"]
  endpoints           = data.talos_client_configuration.this.endpoints

  timeouts = {
    read = "5m"
  }
}

# In-place Talos upgrade — runs talosctl upgrade when the installer image changes.
# Skips the upgrade if the node is already on the target version (first deploy).
resource "terraform_data" "talos_upgrade" {
  for_each = var.nodes

  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this
  ]

  triggers_replace = each.value.installer_image_url

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      TALOSCONFIG=$(mktemp)
      trap 'rm -f "$TALOSCONFIG"' EXIT
      echo "$TALOS_CONFIG_CONTENT" > "$TALOSCONFIG"

      TARGET=$(echo "$IMAGE" | rev | cut -d: -f1 | rev)
      CURRENT=$(talosctl version --nodes "$NODE" --talosconfig "$TALOSCONFIG" --short 2>/dev/null \
        | awk '/^Server:/{found=1} found && /Tag:/{print $2; exit}' || echo "unknown")

      if [ "$CURRENT" = "$TARGET" ]; then
        echo "Node $NODE already on $TARGET, skipping upgrade"
        exit 0
      fi

      echo "Upgrading node $NODE from $CURRENT to $TARGET"
      talosctl upgrade --nodes "$NODE" --image "$IMAGE" --preserve --wait --talosconfig "$TALOSCONFIG"
    EOT
    environment = {
      TALOS_CONFIG_CONTENT = nonsensitive(data.talos_client_configuration.this.talos_config)
      NODE                 = local.resolved_talos_api_ips[each.key]
      IMAGE                = each.value.installer_image_url
    }
  }
}

# Generate kubeconfig for accessing the Kubernetes cluster
resource "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this
  ]

  node                 = local.first_control_plane_api_ip
  client_configuration = talos_machine_secrets.this.client_configuration

  timeouts = {
    read = "1m"
  }
}
