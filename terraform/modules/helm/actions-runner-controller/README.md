<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | 3.2.0 |
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.2.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.actions_runner_controller](https://registry.terraform.io/providers/hashicorp/helm/3.2.0/docs/resources/release) | resource |
| [terraform_data.replace_trigger](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Actions Runner Controller chart version | `string` | n/a | yes |
| <a name="input_github_app_id"></a> [github\_app\_id](#input\_github\_app\_id) | GitHub App ID (must be a string) | `string` | n/a | yes |
| <a name="input_github_app_installation_id"></a> [github\_app\_installation\_id](#input\_github\_app\_installation\_id) | GitHub App Installation ID (must be a string) | `string` | n/a | yes |
| <a name="input_github_app_private_key"></a> [github\_app\_private\_key](#input\_github\_app\_private\_key) | GitHub App private key in PEM format | `string` | n/a | yes |
| <a name="input_replace_triggers"></a> [replace\_triggers](#input\_replace\_triggers) | Values that, when changed, trigger replacement of the Helm release (e.g. cluster kubeconfig to redeploy on cluster rebuild) | `any` | `null` | no |
| <a name="input_values_path"></a> [values\_path](#input\_values\_path) | List of custom values file paths for the ARC helm chart | `list(string)` | `[]` | no |
## Outputs

No outputs.
<!-- END_TF_DOCS -->
