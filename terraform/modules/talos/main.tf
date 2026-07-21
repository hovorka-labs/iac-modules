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
  endpoints            = local.control_plane_ips
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
  control_plane_nodes    = local.control_plane_ips
  worker_nodes           = local.worker_ips
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
# directly. Skips a node's upgrade if it's already on the target image, so a
# fresh bootstrap doesn't immediately try to "upgrade" itself.
#
# One resource for the whole cluster, not one per node — a resource can't
# depend on other instances of itself (Terraform has to fully expand a
# for_each/count before resolving any single instance's dependencies, so a
# same-resource dependency chain is a cycle by construction, not just a
# style choice). Sequencing local.upgrade_order one node at a time therefore
# happens inside the script's own loop, not the Terraform graph — each node
# is upgraded, confirmed back up on the target version, and etcd is confirmed
# healthy across every control plane before the loop moves to the next node,
# so nodes never reboot concurrently and a multi-control-plane cluster never
# risks etcd losing quorum mid-way.
resource "terraform_data" "upgrade" {
  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this,
  ]

  triggers_replace = { for name, node in var.nodes : name => node.installer_image_url }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      TALOSCONFIG=$(mktemp)
      trap 'rm -f "$TALOSCONFIG"' EXIT
      echo "$TALOS_CONFIG_CONTENT" > "$TALOSCONFIG"

      while IFS='|' read -r NODE IMAGE; do
        [ -z "$NODE" ] && continue

        TARGET=$(echo "$IMAGE" | rev | cut -d: -f1 | rev)
        CURRENT=$(talosctl version --nodes "$NODE" --talosconfig "$TALOSCONFIG" --short 2>/dev/null \
          | awk '/^Server:/{found=1} found && /Tag:/{print $2; exit}' || echo "unknown")

        if [ "$CURRENT" = "$TARGET" ]; then
          echo "Node $NODE already on $TARGET, skipping upgrade"
          continue
        fi

        echo "Upgrading node $NODE from $CURRENT to $TARGET"
        # --wait=false on purpose: talosctl upgrade's own --wait tracks the
        # node reaching a "ready" stage that includes Kubernetes' nodeReady
        # condition, which never becomes true without a CNI installed - this
        # module has no opinion on whether one exists, so it can't depend on
        # it. Polling talosctl version below is a Talos-native equivalent
        # that only checks what this module actually owns.
        talosctl upgrade --nodes "$NODE" --image "$IMAGE" --preserve --wait=false --talosconfig "$TALOSCONFIG"

        echo "Waiting for $NODE to come back up on $TARGET"
        UP=""
        for i in $(seq 1 90); do
          sleep 10
          ACTUAL=$(talosctl version --nodes "$NODE" --talosconfig "$TALOSCONFIG" --short 2>/dev/null \
            | awk '/^Server:/{found=1} found && /Tag:/{print $2; exit}' || echo "")
          if [ "$ACTUAL" = "$TARGET" ]; then
            UP="1"
            break
          fi
        done
        if [ -z "$UP" ]; then
          echo "Timed out waiting for $NODE to come back up on $TARGET" >&2
          exit 1
        fi
        echo "$NODE is back up on $TARGET"

        echo "Confirming etcd is healthy on every control plane before moving on to the next node"
        ETCD_STATUS=$(talosctl service etcd --nodes "$CONTROL_PLANE_NODES" --talosconfig "$TALOSCONFIG" 2>&1)
        echo "$ETCD_STATUS"
        if echo "$ETCD_STATUS" | tail -n +2 | awk '{print $4}' | grep -qv "^OK$"; then
          echo "etcd is not healthy on every control plane, stopping here" >&2
          exit 1
        fi
      done <<< "$NODES_LIST"
    EOT
    environment = {
      TALOS_CONFIG_CONTENT = nonsensitive(data.talos_client_configuration.this.talos_config)
      CONTROL_PLANE_NODES  = join(",", local.control_plane_ips)
      WORKER_NODES         = join(",", local.worker_ips)

      # One "ip|image" pair per line, control planes first — the order the
      # script's loop upgrades nodes in.
      NODES_LIST = join("\n", [
        for name in local.upgrade_order :
        "${local.talos_api_ips[name]}|${var.nodes[name].installer_image_url}"
      ])
    }
  }
}
