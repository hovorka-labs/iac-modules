#!/usr/bin/env bash
#
# Operational tooling for a Talos Kubernetes cluster built with the modules
# in this repo (terraform/modules/talos). One file, one entry point - you
# tell it what you want done, it does it, rather than needing to know and
# fetch a different script per operation.
#
# Deliberately outside Terraform entirely. An upgrade (Talos OS or
# Kubernetes) is a multi-minute, multi-node procedure - snapshot etcd, then
# proceed node by node, health-gated between each - and that's a poor fit
# for a Terraform resource: Terraform's model is converging to a declared
# state, not running a multi-step imperative procedure, and an interrupted
# `tofu apply` mid-procedure can leave a node in an unknown state with no
# clean way to resume. This reads/writes real cluster state directly, via
# `tofu output` for the values it needs from your Terraform config.
#
# Single self-contained file on purpose, no separate sourced helper file -
# for something you're expected to curl and run, one atomic download is
# safer than several that could drift out of sync with each other, and it
# means you can read the entire thing before running it.
#
# Usage:
#   ./talos.sh upgrade-talos <cluster-dir>
#   ./talos.sh upgrade-k8s   <cluster-dir> <target-version>
#   ./talos.sh --help
#
#   cluster-dir is always required: the directory you'd normally run
#   `tofu apply` from for this cluster. No default - if you curled this
#   script somewhere else first, the current directory is never that
#   directory, so guessing would be more likely to be wrong than right.
#
# Get it:
#   curl -fsSL https://raw.githubusercontent.com/hovorka-labs/iac-modules/scripts-v1.0.0/scripts/talos.sh -o talos.sh
#   chmod +x talos.sh
#
# Env vars:
#   TALOSCTL              talosctl binary to use (default: talosctl on PATH).
#                          Override when operating multiple clusters/versions
#                          at once - upgrade-k8s requires the client to be at
#                          least as new as the cluster's Talos version, so an
#                          older PATH talosctl can fail checks a newer one
#                          wouldn't.
#   AUTO_CONFIRM=1        skip every confirmation prompt
#   SLEEP_BETWEEN_NODES   seconds to pause between nodes, upgrade-talos only (default 15)
#   NODE_READY_TIMEOUT    kubectl wait timeout per node, upgrade-talos only (default 300s)
#   HEALTH_WAIT_TIMEOUT   talosctl health --wait-timeout (default 10m)

set -euo pipefail

AUTO_CONFIRM="${AUTO_CONFIRM:-0}"
SLEEP_BETWEEN_NODES="${SLEEP_BETWEEN_NODES:-15}"
NODE_READY_TIMEOUT="${NODE_READY_TIMEOUT:-300s}"
HEALTH_WAIT_TIMEOUT="${HEALTH_WAIT_TIMEOUT:-10m}"
TALOSCTL="${TALOSCTL:-talosctl}"

log() { echo -e "\n[$(date +%H:%M:%S)] $*"; }
die() { echo -e "\n!! $* -- aborting." >&2; exit 1; }

usage() {
  cat <<'EOF'
talos.sh - operational tooling for a Talos Kubernetes cluster

Usage:
  talos.sh upgrade-talos <cluster-dir>
      Roll out the Talos OS version already declared (installer_image_url)
      in your Terraform config, one node at a time. Run AFTER bumping the
      version and `tofu apply`-ing it.

  talos.sh upgrade-k8s <cluster-dir> <target-version>
      Upgrade the Kubernetes control plane and kubelets to <target-version>
      (e.g. v1.35.6), via talosctl's own upgrade-k8s. Run BEFORE touching
      k8s_version in Terraform - bump and apply that afterward, to sync the
      declaration with what's now actually running.

  talos.sh --help
      Show this message.
EOF
}

require_bins() {
  local bin
  for bin in "$@"; do command -v "$bin" >/dev/null || die "$bin not found"; done
  [[ "$TALOSCTL" != "talosctl" ]] && log "Using talosctl override: $TALOSCTL ($("$TALOSCTL" version --client --short 2>/dev/null | tail -1))"
  return 0
}

k8s_node_name_for_ip() {
  kubectl get nodes -o json 2>/dev/null | jq -r --arg ip "$1" \
    '.items[] | select(.status.addresses[]?.address==$ip) | .metadata.name'
}

current_talos_tag() {
  "$TALOSCTL" --endpoints "$1" --nodes "$1" version --short 2>/dev/null \
    | awk '/^Server:/{f=1; next} f && /Tag:/{print $2; exit}'
}

current_k8s_version() {
  kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}' 2>/dev/null
}

# VIP reliability during a control-plane reboot varies by provider/network
# setup - sometimes it fails over cleanly, sometimes it doesn't - so rather
# than assume either way, kubectl is always pointed at a real node instead:
# specifically, any control plane OTHER than the one currently being
# upgraded, so asking about cluster state never depends on the one node
# that might be mid-reboot right now.
point_kubectl_away_from() {
  local avoid="$1" target="$FIRST_CP" cand
  for cand in "${CP_IPS[@]}"; do
    if [[ "$cand" != "$avoid" ]]; then target="$cand"; break; fi
  done
  sed -i.bak -E "s#server: .*#server: https://${target}:6443#" "$TMP_DIR/kubeconfig"
  rm -f "$TMP_DIR/kubeconfig.bak"
}

wait_for_apiserver() {
  local timeout="$1" start elapsed
  start=$(date +%s)
  while ! kubectl get --raw='/readyz' &>/dev/null; do
    elapsed=$(( $(date +%s) - start ))
    (( elapsed > timeout )) && return 1
    sleep 5
  done
}

# talosctl health needs CP vs worker roles, or it expects every node to be
# schedulable -- false for CP nodes carrying the default NoSchedule taint.
health_check() {
  "$TALOSCTL" --endpoints "$FIRST_CP" --nodes "$FIRST_CP" \
    health --control-plane-nodes "$CP_CSV" ${WORKER_CSV:+--worker-nodes "$WORKER_CSV"} \
    --k8s-endpoint "$FIRST_CP" --wait-timeout "$1"
}

# etcd can briefly report HEALTH ? ("Unknown") right after its container
# starts, before its first probe has run -- not the same as unhealthy, so
# this retries for a bit instead of failing on the very first check.
etcd_healthy() {
  local status ok="" i
  for i in $(seq 1 12); do
    status=$("$TALOSCTL" --endpoints "$FIRST_CP" --nodes "$CP_CSV" service etcd 2>&1 || true)
    if echo "$status" | grep -q "^HEALTH" && ! echo "$status" | grep "^HEALTH" | grep -qv "OK$"; then
      ok="1"
      break
    fi
    sleep 5
  done
  echo "$status"
  [[ -n "$ok" ]]
}

take_etcd_snapshot() {
  local label="$1"
  log "Taking etcd snapshot (rollback safety net)"
  mkdir -p "$CLUSTER_DIR/etcd-backup"
  "$TALOSCTL" --endpoints "$FIRST_CP" --nodes "$FIRST_CP" etcd snapshot \
    "$CLUSTER_DIR/etcd-backup/${label}-$(date +%Y%m%d-%H%M%S).snapshot" \
    || die "etcd snapshot failed -- not proceeding without a rollback point"
}

preflight() {
  log "Pre-flight: cluster health"
  health_check 2m || die "cluster is not healthy before starting -- fix this first"

  log "Pre-flight: all Kubernetes nodes Ready"
  local not_ready
  not_ready=$(kubectl get nodes -o json | jq -r \
    '.items[] | select(([.status.conditions[]? | select(.type=="Ready") | .status] | contains(["True"])) | not) | .metadata.name')
  [[ -z "$not_ready" ]] || die "node(s) not Ready: $not_ready"

  log "Pre-flight: etcd status"
  etcd_healthy || die "etcd is not healthy before starting -- fix this first"
}

# Fetches kubeconfig/talosconfig/nodes from tofu output for $1, and derives
# CP_CSV/WORKER_CSV/CP_IPS/FIRST_CP. Sets CLUSTER_DIR/TMP_DIR and exports
# KUBECONFIG/TALOSCONFIG. Shared setup for every subcommand.
setup_cluster_access() {
  CLUSTER_DIR="$1"
  [[ -n "$(ls "$CLUSTER_DIR"/*.tf 2>/dev/null)" ]] || die "$CLUSTER_DIR has no .tf files"

  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  log "Fetching kubeconfig/talosconfig/nodes from tofu output ($CLUSTER_DIR)"
  tofu -chdir="$CLUSTER_DIR" output -raw kubeconfig  > "$TMP_DIR/kubeconfig"  || die "tofu output kubeconfig failed -- has this cluster been applied?"
  tofu -chdir="$CLUSTER_DIR" output -raw talosconfig > "$TMP_DIR/talosconfig" || die "tofu output talosconfig failed"
  tofu -chdir="$CLUSTER_DIR" output -json nodes      > "$TMP_DIR/nodes.json"  || die "tofu output nodes failed -- module needs the 'nodes' output (talos-v1.2.0+)"
  chmod 600 "$TMP_DIR/kubeconfig" "$TMP_DIR/talosconfig"
  export KUBECONFIG="$TMP_DIR/kubeconfig" TALOSCONFIG="$TMP_DIR/talosconfig"

  CP_CSV=$(jq -r '[to_entries[] | select(.value.machine_type=="controlplane") | .value.talos_api_ip] | join(",")' "$TMP_DIR/nodes.json")
  WORKER_CSV=$(jq -r '[to_entries[] | select(.value.machine_type=="worker") | .value.talos_api_ip] | join(",")' "$TMP_DIR/nodes.json")
  [[ -n "$CP_CSV" ]] || die "no control-plane nodes in tofu output nodes"
  IFS=',' read -r -a CP_IPS <<< "$CP_CSV"
  FIRST_CP="${CP_IPS[0]}"

  if [[ ${#CP_IPS[@]} -lt 3 ]]; then
    echo "!! Only ${#CP_IPS[@]} control-plane node(s) -- the API server (and kubectl checks) will go fully unreachable while that node reboots."
  fi

  point_kubectl_away_from ""
  log "Cluster: $CLUSTER_DIR"
  log "Control planes: $CP_CSV"
  log "Workers: ${WORKER_CSV:-<none>}"
}

# ---------------------------------------------------------------------------

cmd_upgrade_talos() {
  require_bins "$TALOSCTL" kubectl jq tofu
  [[ -n "${1:-}" ]] || die "cluster-dir required (usage: $0 upgrade-talos <cluster-dir>)"
  setup_cluster_access "$1"

  if [[ "$AUTO_CONFIRM" != "1" ]]; then
    echo "This only rolls out what's already declared - it doesn't bump installer_image_url or run tofu apply for you."
    read -r -p "Have you already set the target installer_image_url and run tofu apply for $CLUSTER_DIR? [y/N] " answer
    echo
    [[ "$answer" =~ ^[Yy]$ ]] || die "bump installer_image_url and tofu apply first, then rerun"
  fi

  preflight
  take_etcd_snapshot "pre-talos-upgrade"

  # Control planes first (etcd quorum must never see two rebooting at once),
  # then workers, both sorted for a stable order across runs.
  local upgrade_order
  upgrade_order=$(jq -r '
    (to_entries | map(select(.value.machine_type=="controlplane")) | sort_by(.key)) +
    (to_entries | map(select(.value.machine_type=="worker"))      | sort_by(.key))
    | .[] | "\(.key)|\(.value.machine_type)|\(.value.talos_api_ip)|\(.value.installer_image_url)"
  ' "$TMP_DIR/nodes.json")

  echo
  echo "Plan:"
  local pending=0 name role ip image target current
  while IFS='|' read -r name role ip image; do
    [[ -z "$name" ]] && continue
    target="${image##*:}"
    current=$(current_talos_tag "$ip" || echo "unknown")
    if [[ "$current" == "$target" ]]; then
      echo "  $name ($role, $ip): already on $target"
    else
      echo "  $name ($role, $ip): $current -> $target"
      pending=$((pending + 1))
    fi
  done <<< "$upgrade_order"
  echo

  if [[ "$pending" -eq 0 ]]; then
    log "Every node already matches its declared installer_image_url. Nothing to do."
    return 0
  fi

  if [[ "$AUTO_CONFIRM" != "1" ]]; then
    read -r -p "Proceed with the upgrade above? [y/N] " answer
    echo
    [[ "$answer" =~ ^[Yy]$ ]] || die "cancelled"
  fi

  local k8s_node
  while IFS='|' read -r name role ip image; do
    [[ -z "$name" ]] && continue
    target="${image##*:}"
    current=$(current_talos_tag "$ip" || echo "unknown")

    log "=== [$role] $name ($ip) ==="
    if [[ "$current" == "$target" ]]; then
      log "-- already on $target, skipping"
      continue
    fi

    point_kubectl_away_from "$ip"
    k8s_node=$(k8s_node_name_for_ip "$ip" || true)

    log "-- talosctl upgrade: $current -> $target"
    "$TALOSCTL" --endpoints "$ip" --nodes "$ip" upgrade --image "$image" --preserve --wait \
      || die "upgrade failed on $name ($ip) -- it may be in a partial state, investigate before continuing"

    wait_for_apiserver 900 || die "API server did not come back within 15m after upgrading $name"

    if [[ -n "$k8s_node" ]]; then
      log "-- waiting for $k8s_node to be Ready"
      kubectl wait --for=condition=Ready "node/$k8s_node" --timeout="$NODE_READY_TIMEOUT" \
        || die "$k8s_node did not become Ready in time"
      # Talos uncordons after its own reboot; this covers leftovers from a
      # previous failed run.
      kubectl uncordon "$k8s_node" 2>/dev/null || true
    fi

    log "-- confirming etcd is healthy on every control plane before continuing"
    etcd_healthy || die "etcd is not healthy on every control plane after upgrading $name"

    log "=== $name done ==="
    sleep "$SLEEP_BETWEEN_NODES"
  done <<< "$upgrade_order"

  point_kubectl_away_from ""
  log "Final verification"
  health_check 2m
  kubectl get nodes -o wide
  log "All nodes now match their declared installer_image_url."
}

cmd_upgrade_k8s() {
  require_bins "$TALOSCTL" kubectl jq tofu
  [[ -n "${1:-}" && -n "${2:-}" ]] || die "usage: $0 upgrade-k8s <cluster-dir> <target-version>"
  setup_cluster_access "$1"
  local target="$2"

  local current
  current=$(current_k8s_version || echo "unknown")
  log "Kubernetes: $current -> $target"

  # Can't check whether k8s_version in Terraform has already been bumped -
  # unlike installer_image_url, it isn't part of this module's own output
  # surface, and the exact variable/local name is caller-specific, so there's
  # nothing generic to grep. What IS generic: if the cluster is already
  # reporting the target version, something's already happened here, whether
  # that's this script running before, a manual upgrade, or Terraform having
  # been applied out of order - worth a harder stop than the usual confirm.
  if [[ "$current" == "$target" ]]; then
    echo "!! Cluster is already reporting $target. If Terraform's k8s_version was bumped and applied before this ran, the order is backwards - upgrade-k8s is meant to run BEFORE that, not after. Re-running this now is harmless (upgrade-k8s is idempotent), but make sure that's actually what you want."
    if [[ "$AUTO_CONFIRM" != "1" ]]; then
      read -r -p "Proceed anyway? [y/N] " answer
      echo
      [[ "$answer" =~ ^[Yy]$ ]] || die "cancelled"
    fi
  elif [[ "$AUTO_CONFIRM" != "1" ]]; then
    read -r -p "This expects k8s_version in Terraform to still be at the OLD version ($current) - confirm you haven't bumped and applied it yet. [y/N] " answer
    echo
    [[ "$answer" =~ ^[Yy]$ ]] || die "if you already bumped k8s_version in Terraform, reconcile that first (see tofu output), then rerun"
  fi

  preflight
  take_etcd_snapshot "pre-k8s-upgrade"

  log "Dry-run: upgrade-k8s --to $target"
  "$TALOSCTL" --nodes "$FIRST_CP" upgrade-k8s --to "$target" --dry-run \
    || die "dry-run failed -- if it's a compatibility error, your talosctl client may be too old for this cluster (see TALOSCTL env var)"

  if [[ "$AUTO_CONFIRM" != "1" ]]; then
    read -r -p "Dry-run above looks right - proceed with the real upgrade to $target? [y/N] " answer
    echo
    [[ "$answer" =~ ^[Yy]$ ]] || die "cancelled"
  fi

  log "Running upgrade-k8s --to $target"
  "$TALOSCTL" --nodes "$FIRST_CP" upgrade-k8s --to "$target" \
    || die "upgrade-k8s failed -- check the output above before retrying"

  log "Final verification"
  health_check "$HEALTH_WAIT_TIMEOUT"
  kubectl get nodes -o wide

  echo
  echo "Kubernetes is now at $target. Terraform still declares the old version, and will keep drifting from reality until you sync it."
  if [[ "$AUTO_CONFIRM" != "1" ]]; then
    while true; do
      read -r -p "Updated k8s_version to \"$target\" and run tofu apply for $CLUSTER_DIR? [y/N] " answer
      echo
      [[ "$answer" =~ ^[Yy]$ ]] && break
      echo "Do that now, then this is done."
    done
  fi
  log "Done."
}

# ---------------------------------------------------------------------------

case "${1:-}" in
  upgrade-talos)
    shift
    cmd_upgrade_talos "$@"
    ;;
  upgrade-k8s)
    shift
    cmd_upgrade_k8s "$@"
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    echo "!! unknown command: $1" >&2
    usage
    exit 1
    ;;
esac
