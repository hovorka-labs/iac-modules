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
  description = "File name image_nodes expects the ISO to be uploaded as on each Proxmox node's datastore."
  value       = local.file_name
}

output "image_nodes" {
  description = "Map of Proxmox node name to the image's file_id, for use in a VM's disk or cdrom block. This module doesn't download the ISO itself - the path is only valid once you've manually uploaded it to that node's datastore under iso_file_name (see the module README). Referencing it before that fails at the Proxmox API when something tries to use it, not here."
  value = {
    for node in local.target_nodes : node => "${var.proxmox_datastore}:iso/${local.file_name}"
  }
}
