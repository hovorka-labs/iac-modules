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
| [helm_release.raw_manifests](https://registry.terraform.io/providers/hashicorp/helm/3.2.0/docs/resources/release) | resource |
## Inputs

| Name | Description | Default | Required |
| ---- | ----------- | ------- | :------: |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Helm release name - required, since this module is reused for different payloads with no sensible shared default | n/a | yes |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Whether to create the namespace if it doesn't already exist - leave false when one of the manifests already declares its own Namespace object | `false` | no |
| <a name="input_manifests"></a> [manifests](#input\_manifests) | Pre-rendered Kubernetes manifests (full YAML documents, as strings) to apply as-is. The caller is responsible for any templating (file()/templatefile()) before passing them in - this module does no templating of its own, it only passes them through. | `[]` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | The namespace Helm records this release under - set it to match whatever namespace the manifests themselves target, even when (as with a cluster-scoped CR) nothing in them actually needs one | `"default"` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Helm install/upgrade timeout in seconds | `600` | no |
## Outputs

No outputs.
<!-- END_TF_DOCS -->
