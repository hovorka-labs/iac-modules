output "talosconfig" {
  description = "Talos client configuration for talosctl"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubernetes configuration for kubectl"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
  depends_on  = [terraform_data.kubernetes_reachable]
}

output "machine_configs" {
  description = "Generated machine configuration for each node"
  value = {
    for name, node in var.nodes : name => data.talos_machine_configuration.this[name].machine_configuration
  }
  sensitive = true
}
