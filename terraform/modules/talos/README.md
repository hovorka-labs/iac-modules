# talos

Bootstraps a Talos Linux Kubernetes cluster: generates machine secrets, renders a machine config per node from a small set of templates, applies it, bootstraps the first control plane node, and waits for the cluster to come up healthy. Talos OS upgrades are handled separately, by `scripts/upgrade-talos.sh` - see below.

**Requires Talos >= 1.12.** Every node's machine config always includes a `HostnameConfig` document, which older Talos versions don't recognize and will reject outright.

## Example

```hcl
module "talos_cluster" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/talos?ref=talos-v1.2.0"

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
- **Upgrades don't happen through Terraform.** Ordinary config changes (`talos_machine_configuration_apply`) are unsequenced across every node, control planes included - a deliberate simplification that trusts the operator to know what a given change does, rather than treating every config apply as potentially disruptive. A Talos OS upgrade is a different animal (multi-minute, multi-node, needs to go one at a time), and a `local-exec` provisioner inside a Terraform resource turned out to be the wrong place to run it - see [Upgrading](#upgrading) below.

## Upgrading

Bump the target node(s)' `installer_image_url` and `tofu apply` as usual - this only updates the *declared* image, it doesn't touch the running OS. Then, from the same directory, run `scripts/upgrade-talos.sh` (fetched alongside the rest of this module - find it under `.terraform/modules/<name>/terraform/modules/talos/scripts/upgrade-talos.sh`) to actually roll the upgrade out: it reads each node's target image from the module's `nodes` output, snapshots etcd, and upgrades one node at a time, gated on Talos *and* Kubernetes health between each. Requires `talosctl`, `kubectl`, `jq`, and `tofu` on your PATH.

```
./upgrade-talos.sh [cluster-dir]   # cluster-dir defaults to the current directory
```

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
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [talos_cluster_kubeconfig.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_secrets.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_secrets) | resource |
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
| <a name="output_nodes"></a> [nodes](#output\_nodes) | Per-node Talos API endpoint, role, and target installer image - consumed by scripts/upgrade-talos.sh |
| <a name="output_talosconfig"></a> [talosconfig](#output\_talosconfig) | Talos client configuration for talosctl |
<!-- END_TF_DOCS -->
