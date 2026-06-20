<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >=3.2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >=3.2.0 |
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.2.0 |
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.cilium](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_labels.kube_system_pod_security](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/labels) | resource |
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Cilium version to use for the cluster | `string` | n/a | yes |
| <a name="input_cilium_values_path"></a> [cilium\_values\_path](#input\_cilium\_values\_path) | List of Cilium values paths | `list(string)` | `[]` | no |
## Outputs

No outputs.
<!-- END_TF_DOCS -->
