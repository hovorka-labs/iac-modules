output "image_file_name" {
  description = "Name of the Talos image file"
  value       = local.file_name
}

output "image_nodes" {
  description = "Map of Proxmox nodes to file paths"
  value = {
    for node, res in proxmox_virtual_environment_download_file.this :
    node => "${var.proxmox_datastore}:${var.content_type}/${local.file_name}"
  }
}

output "image_url" {
  description = "URL to the Talos ISO image"
  value       = data.talos_image_factory_urls.this.urls[var.content_type]
}

output "installer_image_url" {
  description = "URL to the Talos installer image"
  value       = data.talos_image_factory_urls.this.urls["installer"]
}
