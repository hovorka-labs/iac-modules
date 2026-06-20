<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | 0.11.0 |
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.11.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [talos_cluster_kubeconfig.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_secrets.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/resources/machine_secrets) | resource |
| [terraform_data.vm_trigger](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [talos_client_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/data-sources/client_configuration) | data source |
| [talos_cluster_health.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/data-sources/cluster_health) | data source |
| [talos_machine_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/data-sources/machine_configuration) | data source |
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_config"></a> [cluster\_config](#input\_cluster\_config) | Cluster-wide configuration settings | <pre>object({<br/>    api_server                     = optional(string, "")       # API server configuration YAML, merged into the apiServer block (e.g. extraArgs for OIDC)<br/>    api_server_extra_sans          = optional(list(string))     # Extra DNS names to include in the API server certificate SANs<br/>    talos_cluster_name             = string                     # Talos cluster name<br/>    cluster_name                   = string                     # Cluster/region name (used for topology labels)<br/>    cluster_endpoint               = optional(string)           # Explicit cluster endpoint URL (e.g. LB IP); overrides vip and first CP IP<br/>    external_cloud_provider        = optional(bool, false)      # Enable Kubernetes external cloud provider integration (required for cloud CCMs)<br/>    extra_manifests                = optional(list(string), []) # Additional K8s manifests to apply<br/>    gateway_api_version            = string                     # K8s Gateway API version<br/>    kubelet                        = optional(string)           # Kubelet configuration YAML<br/>    vip                            = optional(string)           # Virtual IP for control plane (keepalived)<br/>    allowSchedulingOnControlPlanes = optional(bool, false)      # Allow scheduling on control plane nodes<br/>    disable_kube_proxy             = optional(bool, false)      # Disable kube proxy - useful for Cilium<br/>    pod_subnets                    = optional(list(string), []) # List of Pod CIDRs for the cluster<br/>    service_subnets                = optional(list(string), []) # List of Service CIDRs for the cluster<br/>  })</pre> | n/a | yes |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Map of nodes with their configuration | <pre>map(<br/>    object({<br/>      dns                 = optional(list(string))    # DNS servers<br/>      apply_mode          = string                    # Talos configuration apply mode<br/>      recreation_hash     = string                    # Hash to trigger recreation when VM state changes<br/>      installer_image_url = string                    # Talos installer image URL<br/>      ip                  = string                    # Node cluster IP address<br/>      talos_api_ip        = optional(string)          # IP used to reach the Talos API (defaults to ip); set to public IP when ip is a private address<br/>      node_name           = string                    # Node name (used as topology zone label)<br/>      mac_address         = optional(string, "")      # MAC address for static network config via deviceSelector<br/>      interface_name      = optional(string, "")      # Interface name for static network config (alternative to mac_address)<br/>      use_dhcp            = optional(bool, false)     # Use DHCP instead of static network config<br/>      machine_type        = string                    # Node role: controlplane or worker<br/>      provider_id         = optional(string)          # Cloud provider ID (e.g. hcloud://12345); sets kubelet --provider-id for CCM integration<br/>      k8s_version         = string                    # Kubernetes version<br/>      gateway             = optional(string, "")      # Network gateway IP (required when not using DHCP)<br/>      subnet_mask         = optional(string, "")      # Network subnet mask (required when not using DHCP)<br/>      node_labels         = optional(map(string), {}) # Extra Kubernetes node labels, merged with the topology labels (e.g. for dedicated worker pools)<br/>      node_taints         = optional(map(string), {}) # Extra taints to self-register the node with via kubelet --register-with-taints, as { key = "value:Effect" } (e.g. { dedicated = "dev:NoSchedule" }) — NodeRestriction blocks setting these any other way for worker nodes<br/>    })<br/>  )</pre> | n/a | yes |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubernetes configuration for cluster access |
| <a name="output_machine_configs"></a> [machine\_configs](#output\_machine\_configs) | Generated machine configurations for all nodes |
| <a name="output_talosconfig"></a> [talosconfig](#output\_talosconfig) | Talos client configuration for cluster management |
<!-- END_TF_DOCS -->
