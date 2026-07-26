# talos

Bootstraps a Talos Linux Kubernetes cluster: generates machine secrets, renders a machine config per node from a small set of templates, applies it, bootstraps the first control plane node, and waits for the cluster to come up healthy. Talos and Kubernetes upgrades are handled separately, by [`scripts/talos.sh`](../../../scripts) at the repo root - see below.

## Example

```hcl
module "talos_cluster" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/talos?ref=talos-v1.5.2"

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
- **Upgrades don't happen through Terraform.** A Talos OS upgrade is multi-minute, multi-node, and needs to go one node at a time, which doesn't fit inside a single Terraform resource - see [Upgrading](#upgrading) below for how it's actually handled.

## Upgrading

Get `scripts/talos.sh` from the [repo root](../../../scripts) - it's not part of this module, since it's not Terraform and doesn't need to be fetched through a module source:

```
curl -fsSL https://raw.githubusercontent.com/hovorka-labs/iac-modules/scripts-v1.1.1/scripts/talos.sh -o talos.sh
chmod +x talos.sh
```

**Talos OS upgrade:** bump the target node(s)' `installer_image_url` and `tofu apply` as usual - this only updates the *declared* image, it doesn't touch the running OS. Then, from the same directory:

```
./talos.sh upgrade-talos <cluster-dir>
```

It reads each node's target image from the module's `nodes` output, snapshots etcd, and upgrades one node at a time, gated on Talos *and* Kubernetes health between each.

**Kubernetes upgrade:** run this *before* touching `k8s_version` in Terraform:

```
./talos.sh upgrade-k8s <cluster-dir> <target-version>
```

It snapshots etcd, then drives `talosctl upgrade-k8s` (which sequences the actual component rollout itself). Once it's done, bump `k8s_version` in your Terraform config to match and `tofu apply`, to sync the declaration with what's now actually running.

Both need `talosctl`, `kubectl`, `jq`, and `tofu` on your PATH; set `TALOSCTL=<path>` to use a specific `talosctl` binary instead of whatever's on PATH (useful when operating multiple clusters on different versions). See the script's own `--help` for the full set of env vars.

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
| <a name="output_controlplane_ips"></a> [controlplane\_ips](#output\_controlplane\_ips) | Talos API IPs of every control plane node |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubernetes configuration for kubectl |
| <a name="output_machine_configs"></a> [machine\_configs](#output\_machine\_configs) | Generated machine configuration for each node |
| <a name="output_nodes"></a> [nodes](#output\_nodes) | Per-node Talos API endpoint, role, and target installer image - consumed by scripts/talos.sh at the repo root |
| <a name="output_talosconfig"></a> [talosconfig](#output\_talosconfig) | Talos client configuration for talosctl |
| <a name="output_worker_ips"></a> [worker\_ips](#output\_worker\_ips) | Talos API IPs of every worker node |
<!-- END_TF_DOCS -->
