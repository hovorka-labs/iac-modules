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

- **Single-node clusters** — even with in-place upgrades, the node reboots during the upgrade. With no other node to reschedule workloads onto, this means downtime. etcd also cannot tolerate losing its only member.
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
| Upgrade Talos / Kubernetes | `tofu apply` (per-node version change, see below) |
| Deploy / update Helm charts | `tofu apply` |
| Destroy cluster | `tofu destroy` |
| Back up etcd | `talosctl etcd snapshot` |
| Verify node health during upgrades | `talosctl health` |
| Read node logs / debug issues | `talosctl logs`, `talosctl dmesg` |
| Interactive dashboard | `talosctl dashboard` |
| Disaster recovery (etcd restore, node reset) | `talosctl` |

In short: if it changes desired state, it goes through Terraform. If it reads state or performs an operational action, use `talosctl` or `kubectl`.

## How upgrades work

Each node declares its own `talos_version` and `k8s_version` directly. To upgrade, change the version on one node at a time and apply. Both Talos and Kubernetes upgrades are **in-place** — Talos handles the upgrade through its machine config, no VM recreation required.

```hcl
# In locals.tf — default versions (nodes inherit these unless they override)
talos_version = "v1.12.0"
k8s_version   = "v1.33.3"

# Each node specifies its version explicitly
"cp-01" = {
  # ...
  talos_version = local.talos_version    # or "v1.13.0" during upgrade
  k8s_version   = local.k8s_version     # or "v1.34.0" during upgrade
}
```

### Upgrade procedure (Talos or Kubernetes)

The procedure is the same for both Talos and Kubernetes version upgrades. Changing the version in the machine config triggers Talos to perform the upgrade in-place — the node reboots with the new version without VM recreation.

1. **Back up etcd** before starting:

   ```bash
   talosctl etcd snapshot etcd-backup.snapshot --nodes <cp-ip>
   ```

2. **Upgrade one node at a time** — change the version for a single node, then apply:

   ```hcl
   "cp-01" = {
     talos_version = "v1.13.0"    # upgraded
     k8s_version   = local.k8s_version
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

5. **Update the default** — once all nodes are on the new version, bump the default:

   ```hcl
   talos_version = "v1.13.0"
   ```

   This is cosmetic — all nodes already reference the new version. But it keeps the defaults current for new nodes.

### Important notes

- **Always upgrade control plane nodes first**, one at a time. etcd requires a majority quorum — with 3 control plane nodes, you can only lose 1 at a time.
- **Upgrades are in-place.** Talos downloads the new image, installs to the inactive partition, and reboots. etcd data and node identity are preserved. No VM recreation occurs.
- **Don't skip Talos minor versions.** Talos supports upgrading one minor version at a time (e.g., v1.12 -> v1.13, not v1.12 -> v1.14).
- **Back up etcd** before upgrading control plane nodes: `talosctl etcd snapshot etcd-backup.snapshot --nodes <cp-ip>`
- **The process is intentionally manual and slow.** You change one node at a time so you can verify health at each step. Rollback is straightforward — set the version back to the previous value and apply.

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
