<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | 0.110.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | >= 0.11.0 |
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.110.0 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.11.0 |
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_download_file.this](https://registry.terraform.io/providers/bpg/proxmox/0.110.0/docs/resources/download_file) | resource |
| [talos_image_factory_schematic.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/image_factory_schematic) | resource |
| [talos_image_factory_extensions_versions.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/image_factory_extensions_versions) | data source |
| [talos_image_factory_urls.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/image_factory_urls) | data source |
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_proxmox_nodes"></a> [proxmox\_nodes](#input\_proxmox\_nodes) | List of Proxmox nodes to receive the Talos image | `list(string)` | n/a | yes |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | Talos OS version to use (e.g., v1.9.5) | `string` | n/a | yes |
| <a name="input_content_type"></a> [content\_type](#input\_content\_type) | Content type of the Talos image file | `string` | `"iso"` | no |
| <a name="input_extensions"></a> [extensions](#input\_extensions) | List of Talos extensions to include | `list(string)` | `[]` | no |
| <a name="input_extraKernelArgs"></a> [extraKernelArgs](#input\_extraKernelArgs) | List of extra kernel arguments to pass to Talos | `list(string)` | `[]` | no |
| <a name="input_image_file_name"></a> [image\_file\_name](#input\_image\_file\_name) | Name of the Talos image file (without extension) | `string` | `null` | no |
| <a name="input_image_name_prefix"></a> [image\_name\_prefix](#input\_image\_name\_prefix) | Prefix for the image file name | `string` | `"talos"` | no |
| <a name="input_platform"></a> [platform](#input\_platform) | Platform type for the Talos image | `string` | `"nocloud"` | no |
| <a name="input_proxmox_datastore"></a> [proxmox\_datastore](#input\_proxmox\_datastore) | Proxmox datastore to store the ISO image | `string` | `"local"` | no |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_image_file_name"></a> [image\_file\_name](#output\_image\_file\_name) | Name of the Talos image file |
| <a name="output_image_nodes"></a> [image\_nodes](#output\_image\_nodes) | Map of Proxmox nodes to file paths |
| <a name="output_image_url"></a> [image\_url](#output\_image\_url) | URL to the Talos ISO image |
| <a name="output_installer_image_url"></a> [installer\_image\_url](#output\_installer\_image\_url) | URL to the Talos installer image |
<!-- END_TF_DOCS -->
