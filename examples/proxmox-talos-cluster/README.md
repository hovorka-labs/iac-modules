# Proxmox Talos Kubernetes Cluster

This example deploys a full Talos Linux Kubernetes cluster on Proxmox VE, including:

- **3 control plane + 3 worker** VMs spread across 3 Proxmox nodes
- **Talos image** built with QEMU guest agent and Intel microcode extensions
- **Cilium** as the CNI (replaces kube-proxy, native routing, Gateway API, Hubble)
- **Proxmox CSI** plugin for persistent storage backed by Proxmox LVM
- **Prometheus Operator CRDs** for monitoring integration

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
