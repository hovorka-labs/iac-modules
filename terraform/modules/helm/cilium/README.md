<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12 |
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
| [helm_release.cilium](https://registry.terraform.io/providers/hashicorp/helm/3.2.0/docs/resources/release) | resource |
## Inputs

| Name | Description | Default | Required |
| ---- | ----------- | ------- | :------: |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Cilium version to use for the cluster | n/a | yes |
| <a name="input_cilium_values_path"></a> [cilium\_values\_path](#input\_cilium\_values\_path) | List of Cilium values paths | `[]` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace to deploy the Helm chart to | `"kube-system"` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Helm install/upgrade timeout in seconds | `600` | no |
## Outputs

No outputs.
<!-- END_TF_DOCS -->
