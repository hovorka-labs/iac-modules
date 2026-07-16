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
