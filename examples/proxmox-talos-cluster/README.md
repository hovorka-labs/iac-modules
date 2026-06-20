# Proxmox Talos Kubernetes Cluster

This example deploys a full Talos Linux Kubernetes cluster on Proxmox VE, including:

- **3 control plane + 3 worker** VMs spread across 3 Proxmox nodes
- **Talos image** built with QEMU guest agent and Intel microcode extensions
- **Cilium** as the CNI (replaces kube-proxy, native routing, Gateway API, Hubble)
- **Proxmox CSI** plugin for persistent storage backed by Proxmox LVM
- **Prometheus Operator CRDs** for monitoring integration

## When to use this setup

This setup is designed for **small to medium clusters** (up to ~30 nodes) where managing the full cluster lifecycle through Terraform is a priority. It trades upgrade speed for simplicity and auditability — every change is a Terraform plan you can review before applying.

**Good fit:**

- Homelab / dev / staging environments
- Multi-node clusters (3+ nodes) with HA etcd
- Teams that want a single tool (Terraform) to own the cluster lifecycle
- Clusters up to ~30 nodes where Terraform's plan/apply cycle remains manageable
- Environments where brief maintenance windows during upgrades are acceptable

**Not ideal for:**

- **Single-node clusters** — Talos upgrades recreate VMs, which means total downtime with no other node to reschedule workloads onto. etcd also cannot tolerate losing its only member.
- **Production workloads requiring zero-downtime upgrades** — this setup upgrades nodes by recreating VMs (new disk, fresh Talos install, re-join to cluster). Workloads get rescheduled, but the process takes minutes per node, not seconds.
- **Large clusters (30+ nodes)** — Terraform's plan/apply cycle grows linearly with node count. At that scale, consider a GitOps-based approach with Cluster API or similar tooling that handles rolling upgrades natively.

## Prerequisites

- Proxmox VE cluster with 3+ nodes
- API token with VM and storage permissions
- [OpenTofu](https://opentofu.org/) >= 1.5 (or Terraform)

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Proxmox credentials

tofu init
tofu plan
tofu apply
```

## Accessing the cluster

```bash
# Export kubeconfig
tofu output -raw kubeconfig > kubeconfig.yaml
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Export talosconfig
tofu output -raw talosconfig > talosconfig.yaml
export TALOSCONFIG=$(pwd)/talosconfig.yaml
```

## Customization

- **Node count/sizing**: Edit `locals.tf` — adjust the `nodes` map and `node_configs`
- **Network**: Update `network` in `locals.tf` with your subnet, gateway, and VIP
- **Cilium**: Modify `cilium-values.yaml` (encryption, monitoring, etc.)
- **Storage**: Adjust `proxmox-csi-values.yaml` for your datastore layout
- **Talos extensions**: Add/remove extensions in `talos_extensions`

## What Terraform manages vs what still needs talosctl

The goal of this setup is to keep the cluster **lifecycle** fully in Terraform — provisioning, configuration, upgrades, and teardown are all `tofu apply`. You should not need `talosctl` for any routine change.

However, `talosctl` is still your **operations toolkit** for tasks that are inherently imperative or interactive:

| Task | Tool |
|------|------|
| Provision cluster | `tofu apply` |
| Change node config (versions, extensions, sizing) | `tofu apply` |
| Upgrade Talos / Kubernetes | `tofu apply` (flag-flip, see below) |
| Deploy / update Helm charts | `tofu apply` |
| Destroy cluster | `tofu destroy` |
| Back up etcd | `talosctl etcd snapshot` |
| Verify node health during upgrades | `talosctl health` |
| Read node logs / debug issues | `talosctl logs`, `talosctl dmesg` |
| Interactive dashboard | `talosctl dashboard` |
| Disaster recovery (etcd restore, node reset) | `talosctl` |

In short: if it changes desired state, it goes through Terraform. If it reads state or performs an operational action, use `talosctl` or `kubectl`.

## How upgrades work

This setup uses a **dual-image, per-node flag** strategy for rolling upgrades. Two separate version tracks are maintained side by side:

```hcl
# In locals.tf
talos_version          = "v1.11.0"    # current version
upgraded_talos_version = "v1.12.0"    # version to upgrade to

k8s_version            = "v1.32.0"    # current version
upgraded_k8s_version   = "v1.33.0"    # version to upgrade to
```

Each node has two flags that control which version it uses:

```hcl
"cp-01" = {
  # ...
  upgrade_talos = false   # true = use upgraded_talos_version
  upgrade_k8s   = false   # true = use upgraded_k8s_version
}
```

### Upgrade procedure (Talos version)

A Talos version upgrade rebuilds the VM from a new ISO image — this **recreates the VM** (new disk, fresh Talos install, re-join to cluster). The `recreation_hash` changes when the image changes, triggering a Terraform replace.

1. **Set the target version:**

   ```hcl
   upgraded_talos_version = "v1.12.0"
   ```

2. **Upgrade one node at a time** — flip `upgrade_talos = true` for a single node, then apply:

   ```hcl
   "cp-01" = {
     upgrade_talos = true    # this node gets the new image
     upgrade_k8s   = false
   }
   ```

   ```bash
   tofu apply
   ```

3. **Wait for the node to rejoin** and verify health before moving to the next:

   ```bash
   kubectl get nodes
   talosctl health --nodes <node-ip>
   ```

4. **Repeat for each node** — control plane nodes first (one at a time to maintain etcd quorum), then workers.

5. **Finalize** — once all nodes are upgraded, promote the upgraded version to current and reset the flags:

   ```hcl
   talos_version          = "v1.12.0"
   upgraded_talos_version = "v1.12.0"

   # All nodes back to:
   upgrade_talos = false
   ```

### Upgrade procedure (Kubernetes version)

Kubernetes upgrades are **non-destructive** — they update the Talos machine config with the new `k8s_version`, and Talos handles the kubelet/control-plane component upgrade in place. No VM recreation occurs.

The procedure is the same flag-flip approach:

1. Set `upgraded_k8s_version = "v1.33.0"`
2. Flip `upgrade_k8s = true` one node at a time
3. Apply and verify
4. Finalize by promoting the version

### Important notes

- **Always upgrade control plane nodes first**, one at a time. etcd requires a majority quorum — with 3 control plane nodes, you can only lose 1 at a time.
- **Talos upgrades recreate VMs.** The node gets a fresh disk and re-joins the cluster. Persistent data on the node's local disk is lost (use PVCs with the CSI driver for persistent storage).
- **Kubernetes upgrades do not recreate VMs.** They are applied via Talos machine config reapply, which is much faster and less disruptive.
- **Don't skip Talos minor versions.** Talos supports upgrading one minor version at a time (e.g., v1.11 -> v1.12, not v1.11 -> v1.13).
- **Back up etcd** before upgrading control plane nodes: `talosctl etcd snapshot etcd-backup.snapshot --nodes <cp-ip>`
- **The process is intentionally manual and slow.** You flip one node at a time so you can verify health at each step. This is a feature, not a limitation — it gives you a clear rollback point (just set the flag back to `false`).
- **Always finalize after an upgrade.** Once all nodes are upgraded, promote the upgraded version to current and reset all flags to `false`. If you forget and later bump `upgraded_talos_version` for a new upgrade, any node still set to `upgrade_talos = true` will jump to the new version immediately on the next apply — bypassing the controlled one-at-a-time rollout.

## Architecture

```
Proxmox Node 1          Proxmox Node 2          Proxmox Node 3
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  cp-01 (VM)     │     │  cp-02 (VM)     │     │  cp-03 (VM)     │
│  worker-01 (VM) │     │  worker-02 (VM) │     │  worker-03 (VM) │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        └───────────── VIP (10.0.0.100) ───────────────┘
                    Kubernetes API Server
```

Each Proxmox node runs one control plane and one worker VM. The control plane VIP floats between control plane nodes via Talos's built-in keepalived, providing a stable API endpoint even during node upgrades.
