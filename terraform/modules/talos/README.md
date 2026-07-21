# talos

Bootstraps a Talos Linux Kubernetes cluster: generates machine secrets, renders a machine config per node from a small set of templates, applies it, bootstraps the first control plane node, and waits for the cluster to come up healthy. Also drives in-place `talosctl upgrade`s when a node's installer image changes.

## Example

```hcl
module "talos_cluster" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/talos?ref=talos-v1.0.4"

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

- **`vip` vs `endpoint`.** Every machine config needs a cluster endpoint before the VIP it might describe actually exists. `cluster.endpoint` lets that be pinned explicitly (e.g. an external load balancer); otherwise the module falls back to `cluster.vip`, and finally to the first control plane node's own IP if neither is set.
- **`node_taints`** registers taints via kubelet's `--register-with-taints` instead of a `machine.nodeTaints` patch. Once a worker has registered, NodeRestriction rejects any attempt to change its own taints through the machine config — self-registration is the only path that works reliably for dedicated worker pools.
- **Upgrades run through `talosctl` directly**, via a `local-exec` provisioner keyed on `installer_image_url`. The provider has no native upgrade resource, and the script first checks the node's running version so a fresh bootstrap doesn't try to "upgrade" itself to the version it's already on.
- **`recreation_hash`** feeds a `terraform_data` resource wired up via `replace_triggered_by`, the same pattern as [proxmox/virtual-machines](../proxmox/virtual-machines). It lets a node's machine config be reapplied, and the first control plane's bootstrap redone, by bumping one value instead of depending on an unrelated argument changing.

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
