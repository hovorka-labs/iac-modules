# proxmox/images/talos

Downloads a Talos OS image to one or more Proxmox nodes using the [Talos Image Factory](https://factory.talos.dev). Supports custom extensions and automatically targets all nodes in the cluster when no node list is provided.

## Example

```hcl
provider "proxmox" {
  endpoint  = "https://pve.example.com:8006"
  api_token = "terraform@pve!provider=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  insecure  = true
}

module "talos_image" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/images/talos?ref=proxmox-talos-images-v1.0.0"

  talos_image_version  = "v1.9.5"
  talos_image_platform = "metal"

  talos_image_extensions = [
    "siderolabs/qemu-guest-agent",
  ]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.111 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | ~> 0.11 |
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.111.0 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.11.0 |
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_download_file.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/download_file) | resource |
| [talos_image_factory_schematic.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/image_factory_schematic) | resource |
| [proxmox_virtual_environment_nodes.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/data-sources/virtual_environment_nodes) | data source |
| [talos_image_factory_extensions_versions.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/image_factory_extensions_versions) | data source |
| [talos_image_factory_urls.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/image_factory_urls) | data source |
## Inputs

| Name | Description | Default | Required |
| ---- | ----------- | ------- | :------: |
| <a name="input_talos_image_platform"></a> [talos\_image\_platform](#input\_talos\_image\_platform) | Platform type for the Talos image (e.g., metal, nocloud, vmware) | n/a | yes |
| <a name="input_talos_image_version"></a> [talos\_image\_version](#input\_talos\_image\_version) | Talos OS version to use (e.g., v1.9.5) | n/a | yes |
| <a name="input_proxmox_datastore"></a> [proxmox\_datastore](#input\_proxmox\_datastore) | Proxmox datastore to store the image | `"local"` | no |
| <a name="input_proxmox_nodes"></a> [proxmox\_nodes](#input\_proxmox\_nodes) | Proxmox nodes to download the Talos image to; defaults to all nodes in the cluster | `null` | no |
| <a name="input_talos_image_extensions"></a> [talos\_image\_extensions](#input\_talos\_image\_extensions) | List of Talos extensions to include | `[]` | no |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_image_nodes"></a> [image\_nodes](#output\_image\_nodes) | Map of Proxmox node name to the downloaded image's file\_id, for use in a VM's disk or cdrom block |
| <a name="output_installer_image"></a> [installer\_image](#output\_installer\_image) | Talos installer image URL for use in machine configs |
| <a name="output_schematic_id"></a> [schematic\_id](#output\_schematic\_id) | Talos image factory schematic ID |
<!-- END_TF_DOCS -->
