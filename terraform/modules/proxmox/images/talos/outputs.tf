output "schematic_id" {
  description = "Talos image factory schematic ID"
  value       = talos_image_factory_schematic.this.id
}

output "installer_image" {
  description = "Talos installer image URL for use in machine configs"
  value       = data.talos_image_factory_urls.this.urls.installer
}
