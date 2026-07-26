output "talos_schematic_id" {
  description = "Talos image factory schematic ID for the provisioned image"
  value       = module.talos_image.schematic_id
}

output "talos_installer_image" {
  description = "Talos installer image URL — used in machine configs for upgrades"
  value       = module.talos_image.installer_image
}

output "iso_url" {
  description = "Talos Image Factory ISO URL — fetch and upload this to each Proxmox node before the first apply, see main.tf"
  value       = module.talos_image.iso_url
}

output "iso_file_name" {
  description = "File name to upload the ISO as — see main.tf"
  value       = module.talos_image.iso_file_name
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
