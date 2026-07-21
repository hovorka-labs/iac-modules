output "schematic_id" {
  description = "Talos image factory schematic ID"
  value       = talos_image_factory_schematic.this.id
}

output "installer_image" {
  description = "Talos installer image URL for use in machine configs"
  value       = data.talos_image_factory_urls.this.urls.installer
}

output "image_nodes" {
  description = "Map of Proxmox node name to the downloaded image's file_id, for use in a VM's disk or cdrom block"
  value = {
    for node in keys(proxmox_download_file.this) : node => "${var.proxmox_datastore}:iso/${local.file_name}"
  }
}
