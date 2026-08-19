output "schematic_id" {
  description = "Talos image factory schematic ID"
  value       = talos_image_factory_schematic.this.id
}

output "installer_image" {
  description = "Talos installer image URL for use in machine configs"
  value       = data.talos_image_factory_urls.this.urls.installer
}

output "iso_url" {
  description = "Talos Image Factory URL to download the ISO from. Fetch this and upload it to Proxmox yourself - see the module README for the manual step."
  value       = data.talos_image_factory_urls.this.urls.iso
}

output "iso_file_name" {
  description = "File name to upload the ISO under on each Proxmox node's datastore - see the module README for the manual upload step. Combine with your own datastore name to build a VM's cdrom file_id, e.g. \"$${datastore}:iso/$${iso_file_name}\"."
  value       = local.file_name
}
