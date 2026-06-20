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
| [helm_release.runner_deployment](https://registry.terraform.io/providers/hashicorp/helm/3.2.0/docs/resources/release) | resource |
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_github_org"></a> [github\_org](#input\_github\_org) | GitHub organization name for the runner | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace where the runner deployment will be created | `string` | `"github-runners"` | no |
| <a name="input_runner_labels"></a> [runner\_labels](#input\_runner\_labels) | Labels for the runner | `list(string)` | <pre>[<br/>  "self-hosted",<br/>  "linux"<br/>]</pre> | no |
| <a name="input_runner_replicas"></a> [runner\_replicas](#input\_runner\_replicas) | Number of runner replicas | `number` | `1` | no |
## Outputs

No outputs.
<!-- END_TF_DOCS -->
