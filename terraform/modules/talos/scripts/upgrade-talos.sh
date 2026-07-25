#!/usr/bin/env bash
#
# Rolling Talos OS upgrade for a cluster built with this module.
#
# This deliberately doesn't live inside Terraform as a local-exec
# provisioner. An upgrade is a multi-minute, multi-node procedure -
# snapshot etcd, then one node at a time, health-gated between each - and
# a `tofu apply` running that isn't a safe place for it: an interrupted
# apply mid-upgrade leaves you guessing what state a node is in, with no
# clean way to resume.
# Terraform still owns declaring each node's target installer_image_url
# (see the `nodes` module output); this script reads that declared state
# and reconciles the real cluster to match it, outside Terraform's
# execution model entirely.
#
# Usage: ./upgrade-talos.sh <cluster-dir>
#   cluster-dir is required: the directory you'd normally run `tofu apply`
#   from for this cluster. No default - the path you invoke this script BY
#   is never that directory (it lives nested inside .terraform/modules/...),
#   so guessing "current directory" would be more likely to be wrong than
#   right.
#
# Env vars:
#   TALOSCTL              talosctl binary to use (default: talosctl on PATH).
#                          Override when operating multiple clusters/versions
#                          at once - upgrade-k8s-style commands require the
#                          client to be at least as new as the node's Talos
#                          version, so an older PATH talosctl can fail checks
#                          a newer one wouldn't.
#   AUTO_CONFIRM=1        skip both confirmation prompts (declared-state and plan review)
#   SLEEP_BETWEEN_NODES   seconds to pause between nodes (default 15)
#   NODE_READY_TIMEOUT    kubectl wait timeout per node (default 300s)
#   HEALTH_WAIT_TIMEOUT   talosctl health --wait-timeout (default 10m)

set -euo pipefail

AUTO_CONFIRM="${AUTO_CONFIRM:-0}"
SLEEP_BETWEEN_NODES="${SLEEP_BETWEEN_NODES:-15}"
NODE_READY_TIMEOUT="${NODE_READY_TIMEOUT:-300s}"
HEALTH_WAIT_TIMEOUT="${HEALTH_WAIT_TIMEOUT:-10m}"
TALOSCTL="${TALOSCTL:-talosctl}"

log() { echo -e "\n[$(date +%H:%M:%S)] $*"; }
die() { echo -e "\n!! $* -- aborting." >&2; exit 1; }

[[ -n "${1:-}" ]] || die "cluster-dir required (usage: $0 <cluster-dir>) -- the directory you'd normally run 'tofu apply' from for this cluster"
CLUSTER_DIR="$1"

for bin in "$TALOSCTL" kubectl jq tofu; do
  command -v "$bin" >/dev/null || die "$bin not found"
done
[[ -n "$(ls "$CLUSTER_DIR"/*.tf 2>/dev/null)" ]] || die "$CLUSTER_DIR has no .tf files"
[[ "$TALOSCTL" != "talosctl" ]] && log "Using talosctl override: $TALOSCTL ($("$TALOSCTL" version --client --short 2>/dev/null | tail -1))"

if [[ "$AUTO_CONFIRM" != "1" ]]; then
  echo "This only rolls out what's already declared - it doesn't bump installer_image_url or run tofu apply for you."
  read -r -p "Have you already set the target installer_image_url and run tofu apply for $CLUSTER_DIR? [y/N] " answer
  echo
  [[ "$answer" =~ ^[Yy]$ ]] || die "bump installer_image_url and tofu apply first, then rerun"
fi

tofu_raw()  { tofu -chdir="$CLUSTER_DIR" output -raw  "$1"; }
tofu_json() { tofu -chdir="$CLUSTER_DIR" output -json "$1"; }

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

log "Fetching kubeconfig/talosconfig/nodes from tofu output ($CLUSTER_DIR)"
tofu_raw kubeconfig  > "$TMP_DIR/kubeconfig"  || die "tofu output kubeconfig failed -- has this cluster been applied?"
tofu_raw talosconfig > "$TMP_DIR/talosconfig" || die "tofu output talosconfig failed"
tofu_json nodes      > "$TMP_DIR/nodes.json"  || die "tofu output nodes failed -- module needs the 'nodes' output (talos-v1.2.0+)"
chmod 600 "$TMP_DIR/kubeconfig" "$TMP_DIR/talosconfig"
export KUBECONFIG="$TMP_DIR/kubeconfig" TALOSCONFIG="$TMP_DIR/talosconfig"

CP_CSV=$(jq -r '[to_entries[] | select(.value.machine_type=="controlplane") | .value.talos_api_ip] | join(",")' "$TMP_DIR/nodes.json")
WORKER_CSV=$(jq -r '[to_entries[] | select(.value.machine_type=="worker") | .value.talos_api_ip] | join(",")' "$TMP_DIR/nodes.json")
[[ -n "$CP_CSV" ]] || die "no control-plane nodes in tofu output nodes"
IFS=',' read -r -a CP_IPS <<< "$CP_CSV"
FIRST_CP="${CP_IPS[0]}"

if [[ ${#CP_IPS[@]} -lt 3 ]]; then
  echo "!! Only ${#CP_IPS[@]} control-plane node(s) -- the API server (and this script's kubectl checks) will go fully unreachable while that node reboots."
fi

# Control planes first (etcd quorum must never see two rebooting at once),
# then workers, both sorted for a stable order across runs.
UPGRADE_ORDER=$(jq -r '
  (to_entries | map(select(.value.machine_type=="controlplane")) | sort_by(.key)) +
  (to_entries | map(select(.value.machine_type=="worker"))      | sort_by(.key))
  | .[] | "\(.key)|\(.value.machine_type)|\(.value.talos_api_ip)|\(.value.installer_image_url)"
' "$TMP_DIR/nodes.json")

k8s_node_name_for_ip() {
  kubectl get nodes -o json 2>/dev/null | jq -r --arg ip "$1" \
    '.items[] | select(.status.addresses[]?.address==$ip) | .metadata.name'
}

current_tag() {
  "$TALOSCTL" --endpoints "$1" --nodes "$1" version --short 2>/dev/null \
    | awk '/^Server:/{f=1; next} f && /Tag:/{print $2; exit}'
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

point_kubectl_away_from ""
log "Cluster: $CLUSTER_DIR"
log "Control planes: $CP_CSV"
log "Workers: ${WORKER_CSV:-<none>}"

log "Pre-flight: cluster health"
health_check 2m || die "cluster is not healthy before starting -- fix this first"

log "Pre-flight: all Kubernetes nodes Ready"
NOT_READY=$(kubectl get nodes -o json | jq -r \
  '.items[] | select(([.status.conditions[]? | select(.type=="Ready") | .status] | contains(["True"])) | not) | .metadata.name')
[[ -z "$NOT_READY" ]] || die "node(s) not Ready: $NOT_READY"

log "Pre-flight: etcd status"
etcd_healthy || die "etcd is not healthy before starting -- fix this first"

log "Taking etcd snapshot (rollback safety net)"
mkdir -p "$CLUSTER_DIR/etcd-backup"
"$TALOSCTL" --endpoints "$FIRST_CP" --nodes "$FIRST_CP" etcd snapshot \
  "$CLUSTER_DIR/etcd-backup/pre-upgrade-$(date +%Y%m%d-%H%M%S).snapshot" \
  || die "etcd snapshot failed -- not proceeding without a rollback point"

echo
echo "Plan:"
PENDING=0
while IFS='|' read -r NAME ROLE IP IMAGE; do
  [[ -z "$NAME" ]] && continue
  TARGET="${IMAGE##*:}"
  CURRENT=$(current_tag "$IP" || echo "unknown")
  if [[ "$CURRENT" == "$TARGET" ]]; then
    echo "  $NAME ($ROLE, $IP): already on $TARGET"
  else
    echo "  $NAME ($ROLE, $IP): $CURRENT -> $TARGET"
    PENDING=$((PENDING + 1))
  fi
done <<< "$UPGRADE_ORDER"
echo

if [[ "$PENDING" -eq 0 ]]; then
  log "Every node already matches its declared installer_image_url. Nothing to do."
  exit 0
fi

if [[ "$AUTO_CONFIRM" != "1" ]]; then
  read -r -p "Proceed with the upgrade above? [y/N] " answer
  echo
  [[ "$answer" =~ ^[Yy]$ ]] || die "cancelled"
fi

while IFS='|' read -r NAME ROLE IP IMAGE; do
  [[ -z "$NAME" ]] && continue
  TARGET="${IMAGE##*:}"
  CURRENT=$(current_tag "$IP" || echo "unknown")

  log "=== [$ROLE] $NAME ($IP) ==="
  if [[ "$CURRENT" == "$TARGET" ]]; then
    log "-- already on $TARGET, skipping"
    continue
  fi

  point_kubectl_away_from "$IP"
  K8S_NODE=$(k8s_node_name_for_ip "$IP" || true)

  log "-- talosctl upgrade: $CURRENT -> $TARGET"
  "$TALOSCTL" --endpoints "$IP" --nodes "$IP" upgrade --image "$IMAGE" --preserve --wait \
    || die "upgrade failed on $NAME ($IP) -- it may be in a partial state, investigate before continuing"

  wait_for_apiserver 900 || die "API server did not come back within 15m after upgrading $NAME"

  if [[ -n "$K8S_NODE" ]]; then
    log "-- waiting for $K8S_NODE to be Ready"
    kubectl wait --for=condition=Ready "node/$K8S_NODE" --timeout="$NODE_READY_TIMEOUT" \
      || die "$K8S_NODE did not become Ready in time"
    # Talos uncordons after its own reboot; this covers leftovers from a
    # previous failed run.
    kubectl uncordon "$K8S_NODE" 2>/dev/null || true
  fi

  log "-- confirming etcd is healthy on every control plane before continuing"
  etcd_healthy || die "etcd is not healthy on every control plane after upgrading $NAME"

  log "=== $NAME done ==="
  sleep "$SLEEP_BETWEEN_NODES"
done <<< "$UPGRADE_ORDER"

point_kubectl_away_from ""
log "Final verification"
health_check 2m
kubectl get nodes -o wide
log "All nodes now match their declared installer_image_url."
