# Proxmox Talos Kubernetes Cluster

This example deploys a full Talos Linux Kubernetes cluster on Proxmox VE, including:

- **3 control plane + 3 worker** VMs spread across 3 Proxmox nodes
- **Talos image** built with QEMU guest agent and Intel microcode extensions
- **Cilium** as the CNI (replaces kube-proxy, native routing, Gateway API, Hubble)
- **Proxmox CSI** plugin for persistent storage backed by Proxmox LVM
- **Prometheus Operator CRDs** for monitoring integration

## When to use this setup

This setup is designed for **small to medium homelab clusters** (3-6 nodes) where simplicity and full Terraform-managed lifecycle matter more than zero-downtime upgrades.

**Good fit:**

- Homelab / dev / staging environments
- Multi-node clusters (3+ nodes) with HA etcd
- Teams comfortable with brief maintenance windows during upgrades
- Environments where the entire cluster lifecycle is managed through Terraform

**Not ideal for:**

- **Single-node clusters** — Talos upgrades recreate VMs, which means total downtime with no other node to reschedule workloads onto. etcd also cannot tolerate losing its only member.
- **Production workloads requiring zero-downtime upgrades** — this setup upgrades nodes by recreating VMs (new disk, new image), not via in-place Talos upgrades. Workloads are drained and rescheduled, but the process is not instantaneous.
- **Very large clusters** — Terraform's plan/apply cycle grows linearly with node count. For 20+ nodes, consider a GitOps-based approach with Cluster API or similar.

## Prerequisites

- Proxmox VE cluster with 3+ nodes
- API token with VM and storage permissions
- Terraform >= 1.5 (or OpenTofu)

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Proxmox credentials

terraform init
terraform plan
terraform apply
```

## Accessing the cluster

```bash
# Export kubeconfig
terraform output -raw kubeconfig > kubeconfig.yaml
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Export talosconfig
terraform output -raw talosconfig > talosconfig.yaml
export TALOSCONFIG=$(pwd)/talosconfig.yaml
```

## Customization

- **Node count/sizing**: Edit `locals.tf` — adjust the `nodes` map and `node_configs`
- **Network**: Update `network` in `locals.tf` with your subnet, gateway, and VIP
- **Cilium**: Modify `cilium-values.yaml` (encryption, monitoring, etc.)
- **Storage**: Adjust `proxmox-csi-values.yaml` for your datastore layout
- **Talos extensions**: Add/remove extensions in `talos_extensions`

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
   terraform apply
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
