output "image_nodes" {
  description = "Map of Proxmox nodes to file paths"
  value = {
    for node, res in proxmox_virtual_environment_download_file.this :
    node => "${var.proxmox_datastore}:${var.content_type}/${var.image_file_name}"
  }
}