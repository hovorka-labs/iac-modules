output "schematic_id" {
  description = "Talos image factory schematic ID"
  value       = talos_image_factory_schematic.this.id
}

output "installer_image" {
  description = "Talos installer image URL for use in machine configs"
  value       = data.talos_image_factory_urls.this.urls.installer
}

output "image_nodes" {
  description = "Map of Proxmox node name to the image's file_id, for use in a VM's disk or cdrom block. Valid whether or not download_iso actually downloaded it there - referencing it for a node that doesn't have the file (download_iso = false) fails at the Proxmox API when something tries to use it, not here."
  value = {
    for node in local.target_nodes : node => "${var.proxmox_datastore}:iso/${local.file_name}"
  }
}
