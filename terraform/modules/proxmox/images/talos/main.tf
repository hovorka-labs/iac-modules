data "proxmox_virtual_environment_nodes" "this" {}

locals {
  # proxmox_download_file's default file_name is derived from the URL's last
  # path segment. The Image Factory encodes version and schematic earlier in
  # the URL path, not in that final segment, so the default name is the same
  # for every version/schematic of a given platform+arch - fine on its own,
  # but every image this module downloads would then collide on that one
  # name. An explicit name that embeds the version and schematic keeps each
  # one distinct.
  file_name = "talos-${var.talos_image_version}-${talos_image_factory_schematic.this.id}-${var.talos_image_platform}.iso"

  target_nodes = var.proxmox_nodes != null ? var.proxmox_nodes : toset(data.proxmox_virtual_environment_nodes.this.names)
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
