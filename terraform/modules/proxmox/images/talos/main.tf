data "proxmox_virtual_environment_nodes" "this" {}

locals {
  # proxmox_download_file requires an explicit name; derived from URL by default which is not human-readable
  file_name = "talos-${var.talos_image_version}-${talos_image_factory_schematic.this.id}-${var.talos_image_platform}.iso"
}

data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_image_version
  filters = {
    names = var.talos_image_extensions
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info[*].name
        }
      }
    }
  )
}

data "talos_image_factory_urls" "this" {
  talos_version = var.talos_image_version
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = var.talos_image_platform
}

resource "proxmox_download_file" "this" {
  for_each = var.proxmox_nodes != null ? var.proxmox_nodes : toset(data.proxmox_virtual_environment_nodes.this.names)

  node_name           = each.key
  content_type        = "iso"
  datastore_id        = var.proxmox_datastore
  overwrite_unmanaged = true
  overwrite           = false

  file_name = local.file_name
  url       = data.talos_image_factory_urls.this.urls["iso"]
}
