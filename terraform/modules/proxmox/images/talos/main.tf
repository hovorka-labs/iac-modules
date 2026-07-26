data "proxmox_virtual_environment_nodes" "this" {}

locals {
  # The Image Factory's ISO URL ends in a fixed name that's the same for
  # every version/schematic of a given platform+arch - it encodes those
  # earlier in the path, not in the final segment. Deriving file_name from
  # it directly would mean every version manually uploaded to the same
  # datastore collides on one name. Embedding version and schematic here
  # keeps each one distinct, and is what image_nodes/iso_file_name hand out
  # for that manual upload.
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
