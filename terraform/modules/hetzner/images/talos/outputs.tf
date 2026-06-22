output "iso_name" {
  description = "Hetzner ISO name to attach to servers for initial Talos boot"
  value       = local.effective_iso_name
}

output "installer_image_url" {
  description = "Talos installer image URL (used in machine config for upgrades)"
  value       = data.talos_image_factory_urls.this.urls.installer
}

output "schematic_id" {
  description = "Talos image factory schematic ID"
  value       = local.effective_schematic_id
}
