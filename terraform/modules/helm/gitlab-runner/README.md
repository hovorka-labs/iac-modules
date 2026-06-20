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
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.gitlab-runner](https://registry.terraform.io/providers/hashicorp/helm/3.2.0/docs/resources/release) | resource |
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | GitLab Runner version to use for the cluster | `string` | n/a | yes |
| <a name="input_gitlab_runner_token"></a> [gitlab\_runner\_token](#input\_gitlab\_runner\_token) | Registration token for the GitLab Runner | `string` | `""` | no |
| <a name="input_gitlab_runner_values_path"></a> [gitlab\_runner\_values\_path](#input\_gitlab\_runner\_values\_path) | List of Gitlab Runner values paths | `list(string)` | `[]` | no |
| <a name="input_gitlab_url"></a> [gitlab\_url](#input\_gitlab\_url) | URL of the GitLab instance | `string` | `"https://gitlab.com"` | no |
## Outputs

No outputs.
<!-- END_TF_DOCS -->
