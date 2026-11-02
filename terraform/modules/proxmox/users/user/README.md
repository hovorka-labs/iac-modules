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
| [proxmox_acl.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/acl) | resource |
| [proxmox_virtual_environment_user.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_user) | resource |
## Inputs

| Name | Description | Default | Required |
| ---- | ----------- | ------- | :------: |
| <a name="input_acls"></a> [acls](#input\_acls) | List of ACL objects to assign to the user | n/a | yes |
| <a name="input_user_id"></a> [user\_id](#input\_user\_id) | Proxmox user ID (e.g., user@pve) | n/a | yes |
| <a name="input_comment"></a> [comment](#input\_comment) | Comment for the Proxmox user | `"Managed by Terraform"` | no |
| <a name="input_password"></a> [password](#input\_password) | Password for the Proxmox user | `null` | no |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_user_id"></a> [user\_id](#output\_user\_id) | n/a |
<!-- END_TF_DOCS -->
