<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.111 |
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | ~> 0.111 |
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_user_token.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/user_token) | resource |
## Inputs

| Name | Description | Default | Required |
| ---- | ----------- | ------- | :------: |
| <a name="input_token_name"></a> [token\_name](#input\_token\_name) | Name of the token (e.g. tk1) | n/a | yes |
| <a name="input_user_id"></a> [user\_id](#input\_user\_id) | User ID to which the token belongs (e.g. user@pve) | n/a | yes |
| <a name="input_comment"></a> [comment](#input\_comment) | Optional comment for the token | `"Managed by Terraform"` | no |
| <a name="input_expiration_date"></a> [expiration\_date](#input\_expiration\_date) | RFC3339 timestamp when the token will expire | `null` | no |
| <a name="input_privileges_separation"></a> [privileges\_separation](#input\_privileges\_separation) | Enable privileges separation for the token | `true` | no |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_full_token_id"></a> [full\_token\_id](#output\_full\_token\_id) | The full token identifier in the format user@realm!token\_name |
| <a name="output_token_value"></a> [token\_value](#output\_token\_value) | n/a |
<!-- END_TF_DOCS -->
