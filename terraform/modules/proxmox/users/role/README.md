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
| [proxmox_virtual_environment_role.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_role) | resource |
## Inputs

| Name | Description | Default | Required |
| ---- | ----------- | ------- | :------: |
| <a name="input_privileges"></a> [privileges](#input\_privileges) | List of privileges for the role | n/a | yes |
| <a name="input_role_id"></a> [role\_id](#input\_role\_id) | The ID of the Proxmox role | n/a | yes |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_role_id"></a> [role\_id](#output\_role\_id) | n/a |
<!-- END_TF_DOCS -->
