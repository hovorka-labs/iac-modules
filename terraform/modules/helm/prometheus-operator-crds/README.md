<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | 3.2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 3.2.0 |
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.2.0 |
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.prometheus_crds](https://registry.terraform.io/providers/hashicorp/helm/3.2.0/docs/resources/release) | resource |
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Prometheus Operator CRDs chart version | `string` | n/a | yes |
## Outputs

No outputs.
<!-- END_TF_DOCS -->
