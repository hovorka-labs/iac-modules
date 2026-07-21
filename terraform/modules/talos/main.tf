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

# Workers only - control plane config gets applied by the sequential,
# health-gated terraform_data.control_plane_config_apply below instead.
# Workers restarting kubelet concurrently doesn't risk cluster-wide API
# availability the way concurrent control plane restarts would, so there's
# no need to pay for sequencing here.
resource "talos_machine_configuration_apply" "this" {
  for_each = { for name, node in var.nodes : name => node if node.machine_type == "worker" }

  node                        = local.talos_api_ips[each.key]
  apply_mode                  = each.value.apply_mode
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration

  lifecycle {
    replace_triggered_by = [terraform_data.config_trigger[each.key]]
  }
}

# Control plane config apply, one node at a time - any machine config change
# (not just a Talos/k8s version bump) restarts kube-apiserver, controller
# manager, and scheduler on that node. talos_machine_configuration_apply
# can't be sequenced the same way terraform_data.upgrade is (see that
# resource's comment for why for_each instances can't depend on each other),
# so control planes go through this script instead, using talosctl
# apply-config directly. Talos treats re-applying an identical config as a
# no-op, so applying to every control plane unconditionally on each run is
# safe - the trigger only fires the whole thing when something actually
# changed.
resource "terraform_data" "control_plane_config_apply" {
  triggers_replace = {
    for name in keys(local.control_plane_nodes) :
    name => nonsensitive(data.talos_machine_configuration.this[name].machine_configuration)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      TALOSCONFIG=$(mktemp)
      CONFIGDIR=$(mktemp -d)
      trap 'rm -f "$TALOSCONFIG"; rm -rf "$CONFIGDIR"' EXIT
      echo "$TALOS_CONFIG_CONTENT" > "$TALOSCONFIG"

      # Splits the combined blob into one file per node, named after its IP,
      # plus a sibling .mode file - %%%NODE <ip> <mode> %%% markers delimit
      # each node's rendered config from the next.
      echo "$CONFIGS" | awk -v dir="$CONFIGDIR" '
        /^%%%NODE / {
          split($0, parts, " ")
          node = parts[2]
          mode = parts[3]
          out = dir "/" node ".yaml"
          print mode > (dir "/" node ".mode")
          close(dir "/" node ".mode")
          next
        }
        { print >> out }
      '

      IFS=',' read -ra CP_NODES <<< "$CP_ORDER"
      for NODE in "$${CP_NODES[@]}"; do
        MODE=$(cat "$CONFIGDIR/$NODE.mode")
        echo "Applying machine config to control plane $NODE (mode: $MODE)"
        talosctl apply-config --nodes "$NODE" --file "$CONFIGDIR/$NODE.yaml" --mode "$MODE" --talosconfig "$TALOSCONFIG"

        echo "Confirming etcd is healthy on every control plane before moving on to the next one"
        # See terraform_data.upgrade for why this retries instead of
        # checking once: etcd can briefly report HEALTH ? right after a
        # restart, before its first health probe has run.
        ETCD_OK=""
        for i in $(seq 1 12); do
          ETCD_STATUS=$(talosctl service etcd --nodes "$CONTROL_PLANE_NODES" --talosconfig "$TALOSCONFIG" 2>&1)
          if ! echo "$ETCD_STATUS" | grep "^HEALTH" | grep -qv "OK$"; then
            ETCD_OK="1"
            break
          fi
          sleep 5
        done
        echo "$ETCD_STATUS"
        if [ -z "$ETCD_OK" ]; then
          echo "etcd is not healthy on every control plane, stopping here" >&2
          exit 1
        fi
      done
    EOT
    environment = {
      TALOS_CONFIG_CONTENT = nonsensitive(data.talos_client_configuration.this.talos_config)
      CONTROL_PLANE_NODES  = join(",", local.control_plane_ips)
      CP_ORDER = join(",", [
        for name in local.upgrade_order : local.talos_api_ips[name]
        if var.nodes[name].machine_type == "controlplane"
      ])

      CONFIGS = join("\n", [
        for name in local.upgrade_order :
        "%%%NODE ${local.talos_api_ips[name]} ${var.nodes[name].apply_mode} %%%\n${nonsensitive(data.talos_machine_configuration.this[name].machine_configuration)}"
        if var.nodes[name].machine_type == "controlplane"
      ])
    }
  }
}

# Re-bootstrap only when the first control plane node itself gets rebuilt,
# not on every unrelated config change.
resource "terraform_data" "bootstrap_trigger" {
  input = terraform_data.config_trigger[local.first_control_plane_name].output
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.this,
    terraform_data.control_plane_config_apply,
  ]

  node                 = local.first_control_plane_api_ip
  client_configuration = talos_machine_secrets.this.client_configuration

  lifecycle {
    replace_triggered_by = [terraform_data.bootstrap_trigger]
  }
}

data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_configuration_apply.this,
    terraform_data.control_plane_config_apply,
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
    terraform_data.control_plane_config_apply,
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
        # etcd can briefly report HEALTH ? ("Unknown") right after its
        # container starts, before its first health probe has even run -
        # that's not the same as actually unhealthy, so this retries for a
        # bit instead of failing on the very first check.
        ETCD_OK=""
        for i in $(seq 1 12); do
          ETCD_STATUS=$(talosctl service etcd --nodes "$CONTROL_PLANE_NODES" --talosconfig "$TALOSCONFIG" 2>&1)
          if ! echo "$ETCD_STATUS" | grep "^HEALTH" | grep -qv "OK$"; then
            ETCD_OK="1"
            break
          fi
          sleep 5
        done
        echo "$ETCD_STATUS"
        if [ -z "$ETCD_OK" ]; then
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
