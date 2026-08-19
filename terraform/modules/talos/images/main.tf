locals {
  # Every ISO from the Image Factory has the same file name regardless of
  # version - e.g. "metal-amd64.iso" every time, with the version and
  # schematic only showing up earlier in the URL, not in the file name
  # itself. If we reused that name as-is, uploading a new Talos version to
  # Proxmox would silently overwrite the old ISO instead of sitting next to
  # it. So we build our own name here, with version and schematic baked in,
  # so every upload keeps its own file.
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
