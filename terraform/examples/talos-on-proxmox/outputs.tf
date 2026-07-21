output "talos_schematic_id" {
  description = "Talos image factory schematic ID for the provisioned image"
  value       = module.talos_image.schematic_id
}

output "talos_installer_image" {
  description = "Talos installer image URL — used in machine configs for upgrades"
  value       = module.talos_image.installer_image
}

output "kubeconfig" {
  description = "Kubernetes configuration for kubectl"
  value       = module.talos_cluster.kubeconfig
  sensitive   = true
}

output "talosconfig" {
  description = "Talos client configuration for talosctl"
  value       = module.talos_cluster.talosconfig
  sensitive   = true
}
