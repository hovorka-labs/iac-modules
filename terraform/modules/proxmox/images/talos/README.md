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

## Design notes

- **`download_iso` (default `true`).** The ISO this module downloads is only ever boot media for a VM's first boot - once Talos is installed, upgrades pull the installer image directly over the network and never touch that ISO again. `installer_image`/`schematic_id` are cheap Image Factory API lookups, unrelated to whether the ISO is actually downloaded. So set `download_iso = false` whenever you're calling this module just to declare a new version target (e.g. for an upgrade) rather than actually provisioning a VM - it skips the real network transfer and Proxmox storage use for a file nothing will read. `image_nodes` still returns a valid path either way; if something ends up referencing a file that was never downloaded, that fails at the Proxmox API when it's actually used, not here.

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
| <a name="input_download_iso"></a> [download\_iso](#input\_download\_iso) | Whether to actually download the ISO to Proxmox. The ISO is only ever used as boot media the first time a VM starts - upgrades pull the installer image directly over the network and never touch it again - so set this to false when you only need `installer_image`/`schematic_id` (e.g. to declare a new upgrade target) and aren't provisioning a new VM. | `true` | no |
| <a name="input_proxmox_datastore"></a> [proxmox\_datastore](#input\_proxmox\_datastore) | Proxmox datastore to store the image | `"local"` | no |
| <a name="input_proxmox_nodes"></a> [proxmox\_nodes](#input\_proxmox\_nodes) | Proxmox nodes to download the Talos image to; defaults to all nodes in the cluster | `null` | no |
| <a name="input_talos_image_extensions"></a> [talos\_image\_extensions](#input\_talos\_image\_extensions) | List of Talos extensions to include | `[]` | no |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_image_nodes"></a> [image\_nodes](#output\_image\_nodes) | Map of Proxmox node name to the image's file\_id, for use in a VM's disk or cdrom block. Valid whether or not download\_iso actually downloaded it there - referencing it for a node that doesn't have the file (download\_iso = false) fails at the Proxmox API when something tries to use it, not here. |
| <a name="output_installer_image"></a> [installer\_image](#output\_installer\_image) | Talos installer image URL for use in machine configs |
| <a name="output_schematic_id"></a> [schematic\_id](#output\_schematic\_id) | Talos image factory schematic ID |
<!-- END_TF_DOCS -->
