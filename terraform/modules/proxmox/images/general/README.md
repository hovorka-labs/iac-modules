<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | >=0.110.0 |
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.110.0 |
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_virtual_environment_download_file.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_download_file) | resource |
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_image_file_name"></a> [image\_file\_name](#input\_image\_file\_name) | Name of the image file | `string` | n/a | yes |
| <a name="input_image_url"></a> [image\_url](#input\_image\_url) | Image URL to download the file from | `string` | n/a | yes |
| <a name="input_proxmox_datastore"></a> [proxmox\_datastore](#input\_proxmox\_datastore) | Proxmox datastore to store the ISO image | `string` | n/a | yes |
| <a name="input_proxmox_nodes"></a> [proxmox\_nodes](#input\_proxmox\_nodes) | List of Proxmox nodes to receive the Talos image | `list(string)` | n/a | yes |
| <a name="input_content_type"></a> [content\_type](#input\_content\_type) | Content type of the image file | `string` | `"iso"` | no |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_image_nodes"></a> [image\_nodes](#output\_image\_nodes) | Map of Proxmox nodes to file paths |
<!-- END_TF_DOCS -->
