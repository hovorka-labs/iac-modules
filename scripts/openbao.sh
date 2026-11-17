#!/usr/bin/env bash
#
# Operational tooling for an OpenBao deployment built with the modules in
# this repo (terraform/modules/helm/openbao). One file, one entry point -
# same reasoning as scripts/talos.sh: initializing, unsealing, and seeding
# a vault are imperative, one-time-or-rare procedures, a poor fit for a
# Terraform resource that just wants to converge to a declared state.
#
# Deliberately agnostic about where secret VALUES come from. This script
# never calls a specific password manager's CLI - `seed` reads an
# already-resolved value from stdin, so getting it out of whatever you
# actually use (Proton Pass, Bitwarden, 1Password, a plain local script)
# is one shell pipe away, not something this script needs to know about:
#
#   pass-cli run my-vault/github-token -- ./openbao.sh seed <cluster-dir> secret/argocd/github token
#   bw get notes github-token          | ./openbao.sh seed <cluster-dir> secret/argocd/github token
#   op read "op://vault/item/field"    | ./openbao.sh seed <cluster-dir> secret/argocd/github token
#
# Talks to OpenBao via `kubectl exec` against its pod directly - no local
# `bao` CLI, no port-forward to manage, same "nothing beyond what's already
# on your PATH" spirit as talos.sh.
#
# Usage:
#   ./openbao.sh init        <cluster-dir>
#   ./openbao.sh unseal      <cluster-dir>
#   ./openbao.sh configure   <cluster-dir>
#   ./openbao.sh demo-seed   <cluster-dir>
#   ./openbao.sh seed        <cluster-dir> <kv-path> <key>   (value read from stdin)
#   ./openbao.sh snapshot    <cluster-dir>
#   ./openbao.sh --help
#
#   cluster-dir is always required: the directory you'd normally run an
#   apply from for this cluster. No default, same reasoning as talos.sh.
#
# Get it:
#   curl -fsSL https://raw.githubusercontent.com/hovorka-labs/iac-modules/main/scripts/openbao.sh -o openbao.sh
#   chmod +x openbao.sh
#
# Env vars:
#   TF_BIN                 tofu binary to use (default: tofu on PATH). Set
#                           TF_BIN=terraform if this cluster is managed with
#                           Terraform instead of OpenTofu.
#   OPENBAO_NAMESPACE      namespace OpenBao was installed into (default: openbao)
#   OPENBAO_POD            OpenBao pod to exec into (default: openbao-0)
#   OPENBAO_UNSEAL_KEY     required by `unseal` - the Shamir key, from wherever you keep it
#   OPENBAO_TOKEN          required by `configure`/`demo-seed`/`seed` - a token with
#                           enough privilege (the root token from `init` is simplest
#                           for a single-operator homelab)
#   ESO_NAMESPACE          namespace the external-secrets chart was installed into,
#                           for the ServiceAccount `configure` binds its role to (default: external-secrets)
#   ESO_SERVICE_ACCOUNT    name of that ServiceAccount (default: external-secrets)
#   AUTO_CONFIRM=1         skip confirmation prompts

set -euo pipefail

TF_BIN="${TF_BIN:-tofu}"
OPENBAO_NAMESPACE="${OPENBAO_NAMESPACE:-openbao}"
OPENBAO_POD="${OPENBAO_POD:-openbao-0}"
ESO_NAMESPACE="${ESO_NAMESPACE:-external-secrets}"
ESO_SERVICE_ACCOUNT="${ESO_SERVICE_ACCOUNT:-external-secrets}"
AUTO_CONFIRM="${AUTO_CONFIRM:-0}"

log() { echo -e "\n[$(date +%H:%M:%S)] $*"; }
die() { echo -e "\n!! $* -- aborting." >&2; exit 1; }

usage() {
  cat <<'EOF'
openbao.sh - operational tooling for an OpenBao deployment

Usage:
  openbao.sh init <cluster-dir>
      Initialize OpenBao (1 Shamir key share / 1 threshold - a single
      homelab operator doesn't need more). No-ops if already initialized.
      Prints the unseal key and root token - store them somewhere outside
      the cluster yourself (your password manager of choice); this script
      doesn't do that for you.

  openbao.sh unseal <cluster-dir>
      Unseal OpenBao using OPENBAO_UNSEAL_KEY. No-ops if already unsealed.
      Needed again after every OpenBao pod restart - seal state is
      memory-only, this is inherent to how Vault/OpenBao work, not
      something this script removes.

  openbao.sh configure <cluster-dir>
      Enable OpenBao's Kubernetes auth method and write the policy/role
      External Secrets Operator's ServiceAccount authenticates as - so ESO
      never needs a static credential of its own. Needs OPENBAO_TOKEN.
      Safe to re-run; updates the policy/role in place.

  openbao.sh demo-seed <cluster-dir>
      Seed the one harmless demo value (secret/demo/hello) the example's
      ExternalSecret pulls - no password manager needed. Needs OPENBAO_TOKEN.

  openbao.sh seed <cluster-dir> <kv-path> <key>
      Seed one real secret. Reads the VALUE from stdin - pipe it in from
      whatever you use to hold secrets (see the file header for examples).
      Needs OPENBAO_TOKEN.

  openbao.sh snapshot <cluster-dir>
      Save a Raft snapshot to <cluster-dir>/openbao-backup/ - the PVC
      local-path-provisioner gives OpenBao has zero redundancy, so this is
      the actual backup story. Needs OPENBAO_TOKEN.

  openbao.sh --help
      Show this message.
EOF
}

require_bins() {
  local bin
  for bin in "$@"; do command -v "$bin" >/dev/null || die "$bin not found"; done
}

# Fetches kubeconfig from $TF_BIN output for $1. Sets CLUSTER_DIR/TMP_DIR
# and exports KUBECONFIG. Shared setup for every subcommand.
setup_kube_access() {
  CLUSTER_DIR="$1"
  [[ -n "$(ls "$CLUSTER_DIR"/*.tf 2>/dev/null)" ]] || die "$CLUSTER_DIR has no .tf files"

  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  log "Fetching kubeconfig from $TF_BIN output ($CLUSTER_DIR)"
  "$TF_BIN" -chdir="$CLUSTER_DIR" output -raw kubeconfig > "$TMP_DIR/kubeconfig" \
    || die "$TF_BIN output kubeconfig failed -- has this cluster been applied?"
  chmod 600 "$TMP_DIR/kubeconfig"
  export KUBECONFIG="$TMP_DIR/kubeconfig"

  kubectl get pod "$OPENBAO_POD" -n "$OPENBAO_NAMESPACE" >/dev/null 2>&1 \
    || die "pod $OPENBAO_POD not found in namespace $OPENBAO_NAMESPACE -- has the openbao module been applied? (override with OPENBAO_POD/OPENBAO_NAMESPACE)"
}

bao_exec() {
  kubectl exec -n "$OPENBAO_NAMESPACE" "$OPENBAO_POD" -- env ${OPENBAO_TOKEN:+BAO_TOKEN="$OPENBAO_TOKEN"} bao "$@"
}

bao_exec_stdin() {
  kubectl exec -i -n "$OPENBAO_NAMESPACE" "$OPENBAO_POD" -- env ${OPENBAO_TOKEN:+BAO_TOKEN="$OPENBAO_TOKEN"} bao "$@"
}

is_initialized() {
  kubectl exec -n "$OPENBAO_NAMESPACE" "$OPENBAO_POD" -- bao status -format=json 2>/dev/null \
    | jq -e '.initialized == true' >/dev/null 2>&1
}

require_token() {
  [[ -n "${OPENBAO_TOKEN:-}" ]] || die "OPENBAO_TOKEN is required for this command"
}

# ---------------------------------------------------------------------------

cmd_init() {
  require_bins kubectl jq "$TF_BIN"
  [[ -n "${1:-}" ]] || die "cluster-dir required (usage: $0 init <cluster-dir>)"
  setup_kube_access "$1"

  if is_initialized; then
    log "Already initialized. Nothing to do."
    return 0
  fi

  log "Initializing OpenBao (1 key share / 1 threshold)"
  local result
  result=$(kubectl exec -n "$OPENBAO_NAMESPACE" "$OPENBAO_POD" -- \
    bao operator init -key-shares=1 -key-threshold=1 -format=json) \
    || die "init failed"

  echo
  echo "Unseal key and root token below - store them somewhere outside the cluster"
  echo "(your password manager of choice) and then discard this output:"
  echo
  echo "$result" | jq '{unseal_keys_b64, root_token}'
}

cmd_unseal() {
  require_bins kubectl jq "$TF_BIN"
  [[ -n "${1:-}" ]] || die "cluster-dir required (usage: $0 unseal <cluster-dir>)"
  [[ -n "${OPENBAO_UNSEAL_KEY:-}" ]] || die "OPENBAO_UNSEAL_KEY is required"
  setup_kube_access "$1"

  # No is-it-already-sealed pre-check: `bao operator unseal` is itself
  # idempotent (a no-op reporting current status if already unsealed), so
  # there's nothing to gain from a pre-check and real cost to getting it
  # wrong - `bao status`'s JSON output has proven unreliable to parse
  # straight after a fresh `init` (seen in practice: reported "not sealed"
  # on a vault that had just been initialized, which always leaves a vault
  # sealed - no such thing as init-then-already-unsealed). Always just
  # attempt the unseal and trust its own result.
  log "Unsealing OpenBao"
  kubectl exec -n "$OPENBAO_NAMESPACE" "$OPENBAO_POD" -- bao operator unseal "$OPENBAO_UNSEAL_KEY" \
    || die "unseal failed"
  log "Unsealed."
}

cmd_configure() {
  require_bins kubectl jq "$TF_BIN"
  [[ -n "${1:-}" ]] || die "cluster-dir required (usage: $0 configure <cluster-dir>)"
  require_token
  setup_kube_access "$1"

  # Unlike `vault server -dev`, a real (non-dev) OpenBao/Vault server boots
  # with no "secret/" KV engine mounted at all - every path/ACL convention
  # used elsewhere in this project (secret/data/*, secret/<category>/<app>/...)
  # assumes one exists, so it has to be created explicitly, once, here.
  # Vault/OpenBao report an operation against an unmounted path as a 403 on
  # the internal capability preflight check (not a 404), as a measure
  # against mount enumeration - that 403 is what every kv read/write fails
  # with until this has run.
  log "Enabling the KV v2 secrets engine at secret/ (no-op if already enabled)"
  bao_exec secrets enable -path=secret -version=2 kv 2>/dev/null || true

  log "Enabling the kubernetes auth method (no-op if already enabled)"
  bao_exec auth enable kubernetes 2>/dev/null || true

  log "Pointing it at this cluster's own API server"
  bao_exec write auth/kubernetes/config kubernetes_host="https://kubernetes.default.svc"

  log "Writing the external-secrets policy (read-only, secret/*)"
  printf 'path "secret/data/*" {\n  capabilities = ["read"]\n}\n' \
    | bao_exec_stdin policy write external-secrets -

  log "Binding it to $ESO_SERVICE_ACCOUNT in $ESO_NAMESPACE"
  bao_exec write auth/kubernetes/role/external-secrets \
    bound_service_account_names="$ESO_SERVICE_ACCOUNT" \
    bound_service_account_namespaces="$ESO_NAMESPACE" \
    policies="external-secrets" \
    ttl="1h"

  log "Done. ESO authenticates to OpenBao with no static credential of its own."
}

cmd_demo_seed() {
  require_bins kubectl jq "$TF_BIN"
  [[ -n "${1:-}" ]] || die "cluster-dir required (usage: $0 demo-seed <cluster-dir>)"
  require_token
  setup_kube_access "$1"

  # kv put (not patch, unlike `seed` below) is correct here on purpose:
  # this is the only key ever written to this path, so there's nothing to
  # merge with, and put is guaranteed to create a brand-new path - patch's
  # create-on-missing behavior is the one thing `seed` leaves unverified.
  log "Seeding secret/demo/hello"
  bao_exec kv put secret/demo/hello hello=world
  log "Done. Check it with: kubectl get secret openbao-demo -o jsonpath='{.data.hello}' | base64 -d"
}

cmd_seed() {
  require_bins kubectl jq "$TF_BIN"
  [[ -n "${1:-}" && -n "${2:-}" && -n "${3:-}" ]] || die "usage: $0 seed <cluster-dir> <kv-path> <key>"
  require_token
  setup_kube_access "$1"
  local kv_path="$2" key="$3"

  [[ -t 0 ]] && die "no stdin detected -- pipe the secret value in, e.g.: pass-cli run ... -- $0 seed $1 $kv_path $key"

  # A kv-path often holds more than one key (most real charts have several
  # secrets at the same path), and this gets called once per key - so an
  # existing path needs `kv patch` (merge), not `kv put` (replaces the
  # whole document, clobbering every other key already there). A brand-new
  # path needs `kv put` instead: `kv patch` operates on an existing
  # version and isn't guaranteed to create one from nothing. Check which
  # case this is rather than assume either way.
  local verb="put"
  bao_exec kv get "$kv_path" >/dev/null 2>&1 && verb="patch"

  log "Seeding $kv_path ($key) from stdin ($verb)"
  bao_exec_stdin kv "$verb" "$kv_path" "${key}=-"
  log "Done."
}

cmd_snapshot() {
  require_bins kubectl jq "$TF_BIN"
  [[ -n "${1:-}" ]] || die "cluster-dir required (usage: $0 snapshot <cluster-dir>)"
  require_token
  setup_kube_access "$1"

  local out_dir="$CLUSTER_DIR/openbao-backup"
  local out_file="$out_dir/$(date +%Y%m%d-%H%M%S).snapshot"
  mkdir -p "$out_dir"

  log "Saving Raft snapshot to $out_file"
  kubectl exec -n "$OPENBAO_NAMESPACE" "$OPENBAO_POD" -- env BAO_TOKEN="$OPENBAO_TOKEN" \
    bao operator raft snapshot save /tmp/openbao.snapshot \
    || die "snapshot failed"
  kubectl cp -n "$OPENBAO_NAMESPACE" "$OPENBAO_POD:/tmp/openbao.snapshot" "$out_file" \
    || die "failed to copy snapshot out of the pod"
  kubectl exec -n "$OPENBAO_NAMESPACE" "$OPENBAO_POD" -- rm -f /tmp/openbao.snapshot

  log "Saved: $out_file"
}

# ---------------------------------------------------------------------------

case "${1:-}" in
  init)
    shift
    cmd_init "$@"
    ;;
  unseal)
    shift
    cmd_unseal "$@"
    ;;
  configure)
    shift
    cmd_configure "$@"
    ;;
  demo-seed)
    shift
    cmd_demo_seed "$@"
    ;;
  seed)
    shift
    cmd_seed "$@"
    ;;
  snapshot)
    shift
    cmd_snapshot "$@"
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
