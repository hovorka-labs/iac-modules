<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >=3.1.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >=2.38.0 |
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >=3.1.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >=2.38.0 |
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.proxmox_csi_plugin](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_labels.csi_proxmox_pod_security](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/labels) | resource |
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | proxmox-csi-plugin chart version | `string` | n/a | yes |
| <a name="input_proxmox_region"></a> [proxmox\_region](#input\_proxmox\_region) | Proxmox region (cluster name) | `string` | n/a | yes |
| <a name="input_proxmox_token_id"></a> [proxmox\_token\_id](#input\_proxmox\_token\_id) | Proxmox API token ID (user@realm!token\_name) | `string` | n/a | yes |
| <a name="input_proxmox_token_secret"></a> [proxmox\_token\_secret](#input\_proxmox\_token\_secret) | Proxmox API token secret | `string` | n/a | yes |
| <a name="input_proxmox_url"></a> [proxmox\_url](#input\_proxmox\_url) | Proxmox API URL | `string` | n/a | yes |
| <a name="input_proxmox_insecure"></a> [proxmox\_insecure](#input\_proxmox\_insecure) | Skip TLS verification for Proxmox API | `bool` | `false` | no |
| <a name="input_values_path"></a> [values\_path](#input\_values\_path) | List of values file paths | `list(string)` | `[]` | no |
## Outputs

No outputs.
<!-- END_TF_DOCS -->
