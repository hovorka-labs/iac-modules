resource "proxmox_virtual_environment_download_file" "this" {
  for_each = toset(var.proxmox_nodes)

  node_name           = each.key
  content_type        = var.content_type
  datastore_id        = var.proxmox_datastore
  overwrite_unmanaged = true
  overwrite           = false

  file_name = var.image_file_name
  url       = var.image_url
}
