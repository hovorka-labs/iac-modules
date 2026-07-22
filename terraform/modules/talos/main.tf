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

# Applied unsequenced to every node, control planes included - only Talos
# OS upgrades (terraform_data.upgrade below) are sequenced and health-gated.
# An ordinary config change can restart a control plane's kube-apiserver,
# controller-manager, and scheduler, so applying to every control plane at
# once isn't risk-free, but it's a deliberate simplification: the operator
# is expected to know what a given change does before applying it, and only
# a guaranteed-disruptive OS upgrade gets the extra sequencing machinery.
resource "talos_machine_configuration_apply" "this" {
  for_each = var.nodes

  node                        = local.talos_api_ips[each.key]
  apply_mode                  = each.value.apply_mode
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
}

# Re-bootstrap only when the first control plane node itself gets rebuilt,
# not on every unrelated config change.
resource "terraform_data" "bootstrap_trigger" {
  input = try(var.nodes[local.first_control_plane_name].recreation_hash, "default")
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.this,
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

  # Nothing before this point actually confirms the Kubernetes API is
  # reachable through cluster_endpoint (the VIP, if one is set) - bootstrap
  # and cluster_health both only ever talk to the Talos API directly, never
  # Kubernetes. keepalived only assigns the VIP to a node once that node's
  # own kube-apiserver passes its health check, which takes a few seconds
  # after bootstrap, so a consumer that immediately tries to use the
  # kubeconfig output (e.g. a helm_release depending on this module) can
  # hit a bare connection refused. Unlike the checks this module
  # deliberately skips elsewhere, this has nothing to do with node
  # readiness or a CNI - the API server comes up on its own, so it's safe
  # to wait for right here rather than needing a dedicated resource.
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      for i in $(seq 1 24); do
        if curl -sk --connect-timeout 5 --max-time 10 -o /dev/null "https://$CLUSTER_ENDPOINT:6443/version"; then
          echo "Kubernetes API is reachable through $CLUSTER_ENDPOINT"
          exit 0
        fi
        sleep 5
      done

      echo "Kubernetes API never became reachable through $CLUSTER_ENDPOINT" >&2
      exit 1
    EOT
    environment = {
      CLUSTER_ENDPOINT = local.cluster_endpoint
    }
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
        # --endpoints pins every call below to $NODE itself instead of
        # letting talosctl route through any configured control plane - one
        # of the others can be mid-reboot from an earlier iteration of this
        # same loop, and a routing failure there has nothing to do with
        # whether $NODE itself is reachable.
        CURRENT=$(talosctl version --nodes "$NODE" --endpoints "$NODE" --talosconfig "$TALOSCONFIG" --short 2>/dev/null \
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
        talosctl upgrade --nodes "$NODE" --endpoints "$NODE" --image "$IMAGE" --preserve --wait=false --talosconfig "$TALOSCONFIG"

        echo "Waiting for $NODE to come back up on $TARGET"
        UP=""
        for i in $(seq 1 90); do
          sleep 10
          ACTUAL=$(talosctl version --nodes "$NODE" --endpoints "$NODE" --talosconfig "$TALOSCONFIG" --short 2>/dev/null \
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
        # bit instead of failing on the very first check. The "|| true"
        # and the explicit "^HEALTH" check below it both matter: if
        # talosctl itself fails here, an empty ETCD_STATUS must count as
        # "not yet healthy", not silently pass as if it were.
        ETCD_OK=""
        for i in $(seq 1 12); do
          ETCD_STATUS=$(talosctl service etcd --nodes "$CONTROL_PLANE_NODES" --talosconfig "$TALOSCONFIG" 2>&1 || true)
          if echo "$ETCD_STATUS" | grep -q "^HEALTH" && ! echo "$ETCD_STATUS" | grep "^HEALTH" | grep -qv "OK$"; then
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
