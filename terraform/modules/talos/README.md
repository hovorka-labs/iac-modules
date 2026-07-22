# talos

Bootstraps a Talos Linux Kubernetes cluster: generates machine secrets, renders a machine config per node from a small set of templates, applies it, bootstraps the first control plane node, and waits for the cluster to come up healthy. Also drives in-place `talosctl upgrade`s when a node's installer image changes.

**Requires Talos >= 1.12.** Every node's machine config always includes a `HostnameConfig` document, which older Talos versions don't recognize and will reject outright.

## Example

```hcl
module "talos_cluster" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/talos?ref=talos-v1.1.2"

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
- **`kubeconfig` waits for the Kubernetes API to actually answer** through `cluster_endpoint` before the output resolves. Bootstrap and cluster health both only talk to the Talos API directly, so without this, a consumer that immediately deploys something against the returned kubeconfig (e.g. a `helm_release` depending on this module) can hit a bare connection refused, since keepalived only assigns the VIP once the local kube-apiserver passes its own health check. Unlike the checks this module deliberately skips elsewhere, this one has nothing to do with node readiness or a CNI - the API server comes up on its own.
- **Upgrades** (`terraform_data.upgrade`) are the only sequenced, health-gated operation - one node at a time, through `talosctl` directly, gated on etcd reporting healthy before moving to the next, since concurrent control-plane reboots risk etcd's quorum. Ordinary config changes (`talos_machine_configuration_apply`) are unsequenced across every node, control planes included - a deliberate simplification that trusts the operator to know what a given change does, rather than treating every config apply as potentially disruptive.
- **`recreation_hash`** only matters on the first control plane node (whichever one happens to come first in the `nodes` map): it feeds `bootstrap_trigger`, a `terraform_data` resource wired up via `replace_triggered_by`, the same pattern as [proxmox/virtual-machines](../proxmox/virtual-machines) - bump it to redo the cluster bootstrap without needing an unrelated argument to change first, e.g. after that node's underlying VM gets rebuilt. It's a no-op on every other node; ordinary config reapplication just relies on the rendered config content itself changing.

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
| [terraform_data.kubernetes_reachable](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.upgrade](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [talos_client_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/client_configuration) | data source |
| [talos_cluster_health.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/cluster_health) | data source |
| [talos_machine_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |
## Inputs

| Name | Description | Default | Required |
| ---- | ----------- | ------- | :------: |
| <a name="input_cluster"></a> [cluster](#input\_cluster) | Cluster-wide configuration shared by every node | n/a | yes |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Map of nodes to configure. The map key is used as the node's identity (hostname, topology zone label unless overridden by zone). | n/a | yes |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubernetes configuration for kubectl |
| <a name="output_machine_configs"></a> [machine\_configs](#output\_machine\_configs) | Generated machine configuration for each node |
| <a name="output_talosconfig"></a> [talosconfig](#output\_talosconfig) | Talos client configuration for talosctl |
<!-- END_TF_DOCS -->
