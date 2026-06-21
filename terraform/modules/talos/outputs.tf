# Talos client configuration for talosctl
output "talosconfig" {
  description = "Talos client configuration for cluster management"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

# Kubernetes client configuration for kubectl
output "kubeconfig" {
  description = "Kubernetes configuration for cluster access"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

# Changes when the cluster is rebuilt (bootstrap replaced) — use as replace_triggers
# for Helm modules to ensure they redeploy after an all-at-once Talos upgrade
output "cluster_identity" {
  description = "Opaque value that changes when the cluster is rebuilt"
  value       = talos_machine_bootstrap.this.id
}

# Machine configurations for all nodes
output "machine_configs" {
  description = "Generated machine configurations for all nodes"
  value = {
    for name, node in var.nodes : name => data.talos_machine_configuration.this[name].machine_configuration
  }
  sensitive = true # Machine configs can contain sensitive information
}
