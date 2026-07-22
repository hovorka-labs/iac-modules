# talos

Bootstraps a Talos Linux Kubernetes cluster: generates machine secrets, renders a machine config per node from a small set of templates, applies it, bootstraps the first control plane node, and waits for the cluster to come up healthy. Also drives in-place `talosctl upgrade`s when a node's installer image changes.

## Example

```hcl
module "talos_cluster" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/talos?ref=talos-v1.0.11"

  cluster = {
    name                 = "hub"
    region               = "hovorkalabs"
    vip                  = "192.168.1.10"
    gateway_api_version  = "v1.2.1"
    pod_subnets          = ["10.244.0.0/16"]
    service_subnets      = ["10.96.0.0/12"]
    disable_kube_proxy   = true
  }

  nodes = {
    talos-cp-1 = {
      machine_type         = "controlplane"
      ip                   = "192.168.1.11"
      mac_address          = "bc:24:11:00:00:01"
      gateway              = "192.168.1.1"
      subnet_mask          = "24"
      installer_image_url  = module.talos_image.installer_image
      k8s_version          = "1.31.4"
    }

    talos-worker-1 = {
      machine_type         = "worker"
      ip                   = "192.168.1.21"
      mac_address          = "bc:24:11:00:00:02"
      gateway              = "192.168.1.1"
      subnet_mask          = "24"
      installer_image_url  = module.talos_image.installer_image
      k8s_version          = "1.31.4"
    }
  }
}
```

## Design notes

For the full write-up behind these decisions, see [Homelab Diary Part 4](https://jakubhovorka.cloud/posts/homelab-diary-part-4/).

- **`zone`** defaults to the node's own map key, but override it to the real Proxmox node name if you're running Proxmox CSI or CCM - both call the Proxmox API using `topology.kubernetes.io/zone` directly as a node name.
- **`vip` vs `endpoint`.** `cluster.endpoint` pins the cluster endpoint explicitly; otherwise it falls back to `cluster.vip`, then the first control plane's own IP.
- **`node_taints`** registers taints via kubelet's `--register-with-taints` rather than a `machine.nodeTaints` patch - NodeRestriction rejects the latter once a worker has registered.
- **Upgrades** (`terraform_data.upgrade`) and **control plane config application** (`terraform_data.control_plane_config_apply`) both go through `talosctl` directly, one node at a time, gated on etcd reporting healthy before moving to the next - concurrent control-plane restarts risk etcd's quorum. Workers apply config through the native `talos_machine_configuration_apply` resource instead, since restarting a worker's kubelet doesn't carry the same risk.
- **`recreation_hash`** feeds a `terraform_data` resource wired up via `replace_triggered_by`, the same pattern as [proxmox/virtual-machines](../proxmox/virtual-machines) - reapply a node's config, or redo the first control plane's bootstrap, by bumping one value.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | ~> 0.11 |
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.11.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [talos_cluster_kubeconfig.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_secrets.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_secrets) | resource |
| [terraform_data.bootstrap_trigger](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.config_trigger](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.control_plane_config_apply](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.upgrade](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [talos_client_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/client_configuration) | data source |
| [talos_cluster_health.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/cluster_health) | data source |
| [talos_machine_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |
## Inputs

| Name | Description | Default | Required |
| ---- | ----------- | ------- | :------: |
| <a name="input_cluster"></a> [cluster](#input\_cluster) | Cluster-wide configuration shared by every node | n/a | yes |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Map of nodes to configure. The map key is used as the node's topology zone label. | n/a | yes |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubernetes configuration for kubectl |
| <a name="output_machine_configs"></a> [machine\_configs](#output\_machine\_configs) | Generated machine configuration for each node |
| <a name="output_talosconfig"></a> [talosconfig](#output\_talosconfig) | Talos client configuration for talosctl |
<!-- END_TF_DOCS -->
