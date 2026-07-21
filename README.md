# IaC Modules

Reusable Terraform modules and Ansible roles for homelab and self-hosted infrastructure.

## Usage

Reference any module from your Terraform configuration via git:

```hcl
module "talos_cluster" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/talos?ref=v0.6.0"
  # ...
}
```

Pin to a [release tag](https://github.com/hovorka-labs/iac-modules/tags) with `?ref=vX.Y.Z`.

## Terraform Modules

### Proxmox

| Module | Description |
|--------|-------------|
| [proxmox/virtual-machines](terraform/modules/proxmox/virtual-machines) | Create and manage Proxmox VMs |
| [proxmox/images/talos](terraform/modules/proxmox/images/talos) | Build and upload Talos Linux images with extensions |
| [proxmox/images/general](terraform/modules/proxmox/images/general) | Download generic images to Proxmox nodes |
| [proxmox/users/role](terraform/modules/proxmox/users/role) | Manage Proxmox roles and privileges |
| [proxmox/users/user](terraform/modules/proxmox/users/user) | Manage Proxmox users and ACLs |
| [proxmox/users/user-token](terraform/modules/proxmox/users/user-token) | Manage Proxmox API tokens |

### Kubernetes / Talos

| Module | Description |
|--------|-------------|
| [talos](terraform/modules/talos) | Bootstrap a Talos Linux Kubernetes cluster |

### Helm Charts

| Module | Description |
|--------|-------------|
| [helm/cilium](terraform/modules/helm/cilium) | Deploy Cilium CNI |
| [helm/proxmox-csi-plugin](terraform/modules/helm/proxmox-csi-plugin) | Deploy Proxmox CSI storage driver |
| [helm/prometheus-operator-crds](terraform/modules/helm/prometheus-operator-crds) | Install Prometheus Operator CRDs |
| [helm/gitlab-runner](terraform/modules/helm/gitlab-runner) | Deploy GitLab Runner |
| [helm/actions-runner-controller](terraform/modules/helm/actions-runner-controller) | Deploy GitHub Actions Runner Controller |
| [helm/actions-runner-deployment](terraform/modules/helm/actions-runner-deployment) | Deploy GitHub Actions Runner workloads |

## Ansible Roles

*Coming soon* — roles will live under `ansible/roles/`.

## Examples

| Example | What it builds |
|---------|----------------|
| [talos-on-proxmox](terraform/examples/talos-on-proxmox) | Talos images + VMs on Proxmox, built up step by step in the Homelab Diary blog series |

## Development

```bash
# Install pre-commit hooks
brew install pre-commit tflint terraform-docs trivy
pre-commit install

# Run all checks
pre-commit run --all-files
```
