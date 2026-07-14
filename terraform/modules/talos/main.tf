locals {
  control_plane_nodes = { for name, node in var.nodes : name => node if node.machine_type == "controlplane" }

  first_control_plane_name = keys(local.control_plane_nodes)[0]

  # Talos API endpoint per node — defaults to the cluster IP, but can be
  # overridden when it isn't directly reachable, e.g. a private IP behind a
  # public one on Hetzner.
  talos_api_ips = {
    for name, node in var.nodes : name => try(node.talos_api_ip, node.ip)
  }

  first_control_plane_api_ip = local.talos_api_ips[local.first_control_plane_name]

  # Endpoint baked into every machine config: an explicit override wins, then
  # the VIP, then just the first control plane node's IP.
  cluster_endpoint = coalesce(
    var.cluster.endpoint,
    var.cluster.vip,
    local.control_plane_nodes[local.first_control_plane_name].ip
  )

  # provider-id identifies the node to a cloud controller manager (e.g.
  # hcloud://<id> for Hetzner's CCM); irrelevant without one, e.g. on Proxmox.
  #
  # register-with-taints is for dedicated worker pools and applies everywhere.
  # NodeRestriction forbids a kubelet from changing its own node's taints
  # after registration (a machine.nodeTaints patch gets rejected), so setting
  # them at kubelet startup is the only mechanism that reliably works.
  kubelet_extra_args = {
    for name, node in var.nodes : name => merge(
      node.provider_id != null ? { "provider-id" = node.provider_id } : {},
      length(node.node_taints) > 0 ? {
        "register-with-taints" = join(",", [for k, v in node.node_taints : "${k}=${v}"])
      } : {}
    )
  }

  # Applied before Kubernetes even exists, so anything that needs these CRDs
  # during cluster bootstrap doesn't hit a chicken-and-egg problem waiting on
  # them.
  gateway_api_manifests = [
    "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.cluster.gateway_api_version}/standard-install.yaml",
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${var.cluster.gateway_api_version}/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml",
  ]

  node_config_patches = {
    for name, node in var.nodes : name => concat(
      [
        templatefile("${path.module}/templates/machine-config/common.yaml.tftpl", {
          node_name           = name
          region              = var.cluster.region
          k8s_version         = node.k8s_version
          installer_image_url = node.installer_image_url
          machine_type        = node.machine_type
          disable_kube_proxy  = var.cluster.disable_kube_proxy
          node_labels         = node.node_labels
        })
      ],
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
          vip                               = var.cluster.vip
          api_server_extra_sans             = var.cluster.api_server_extra_sans
          api_server_config                 = var.cluster.api_server_config
          allow_scheduling_on_controlplanes = var.cluster.allow_scheduling_on_controlplanes
          external_cloud_provider           = var.cluster.external_cloud_provider
          extra_manifests                   = jsonencode(concat(var.cluster.extra_manifests, local.gateway_api_manifests))
          pod_subnets                       = var.cluster.pod_subnets
          service_subnets                   = var.cluster.service_subnets
          ip                                = node.ip
          mac_address                       = lower(node.mac_address)
          interface_name                    = node.interface_name
          use_dhcp                          = node.use_dhcp
          gateway                           = node.gateway
          subnet_mask                       = node.subnet_mask
        })
        ] : [
        templatefile("${path.module}/templates/machine-config/worker.yaml.tftpl", {
          ip             = node.ip
          mac_address    = lower(node.mac_address)
          interface_name = node.interface_name
          use_dhcp       = node.use_dhcp
          gateway        = node.gateway
          subnet_mask    = node.subnet_mask
        })
      ]
    )
  }
}

# Forces a node's machine configuration to be reapplied on demand, without
# depending on an unrelated config change to trigger it.
resource "terraform_data" "config_trigger" {
  for_each = var.nodes
  input = {
    hash = try(each.value.recreation_hash, "default")
  }
}

resource "talos_machine_secrets" "this" {}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for ip in local.talos_api_ips : ip]
  endpoints            = [for name, ip in local.talos_api_ips : ip if var.nodes[name].machine_type == "controlplane"]
}

data "talos_machine_configuration" "this" {
  for_each = var.nodes

  cluster_name     = var.cluster.name
  cluster_endpoint = "https://${local.cluster_endpoint}:6443"
  machine_type     = each.value.machine_type
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches   = local.node_config_patches[each.key]
}

resource "talos_machine_configuration_apply" "this" {
  for_each = var.nodes

  node                        = local.talos_api_ips[each.key]
  apply_mode                  = each.value.apply_mode
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration

  lifecycle {
    replace_triggered_by = [terraform_data.config_trigger[each.key]]
  }
}

# Re-bootstrap only when the first control plane node itself gets rebuilt,
# not on every unrelated config change.
resource "terraform_data" "bootstrap_trigger" {
  input = terraform_data.config_trigger[local.first_control_plane_name].output
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.this]

  node                 = local.first_control_plane_api_ip
  client_configuration = talos_machine_secrets.this.client_configuration

  lifecycle {
    replace_triggered_by = [terraform_data.bootstrap_trigger]
  }
}

data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this,
  ]

  skip_kubernetes_checks = true
  client_configuration   = data.talos_client_configuration.this.client_configuration
  control_plane_nodes    = [for name, ip in local.talos_api_ips : ip if var.nodes[name].machine_type == "controlplane"]
  worker_nodes           = [for name, ip in local.talos_api_ips : ip if var.nodes[name].machine_type == "worker"]
  endpoints              = data.talos_client_configuration.this.endpoints

  timeouts = {
    read = "5m"
  }
}

# The provider has no native upgrade resource, so this shells out to talosctl
# directly. Skips the upgrade if the node is already on the target image, so
# a fresh bootstrap doesn't immediately try to "upgrade" itself.
resource "terraform_data" "upgrade" {
  for_each = var.nodes

  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this,
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
      NODE                 = local.talos_api_ips[each.key]
      IMAGE                = each.value.installer_image_url
    }
  }
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this,
  ]

  node                 = local.first_control_plane_api_ip
  client_configuration = talos_machine_secrets.this.client_configuration

  timeouts = {
    read = "1m"
  }
}
