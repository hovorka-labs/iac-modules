output "talosconfig" {
  description = "Talos client configuration for talosctl"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubernetes configuration for kubectl"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "machine_configs" {
  description = "Generated machine configuration for each node"
  value = {
    for name, node in var.nodes : name => data.talos_machine_configuration.this[name].machine_configuration
  }
  sensitive = true
}

output "nodes" {
  description = "Per-node Talos API endpoint, role, and target installer image - consumed by scripts/upgrade-talos.sh"
  value = {
    for name, node in var.nodes : name => {
      talos_api_ip        = local.talos_api_ips[name]
      machine_type        = node.machine_type
      installer_image_url = node.installer_image_url
    }
  }
}
