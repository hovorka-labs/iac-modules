locals {
  effective_schematic_id = var.schematic_id != null ? var.schematic_id : talos_image_factory_schematic.this[0].id
  effective_iso_name     = coalesce(var.iso_name, "talos-${var.talos_version}-hcloud-amd64")
}

# Get compatible extension versions for this Talos release.
# Only needed when building a custom schematic.
data "talos_image_factory_extensions_versions" "this" {
  count = var.schematic_id == null && length(var.extensions) > 0 ? 1 : 0

  talos_version = var.talos_version
  filters = {
    names = var.extensions
  }
}

# Build a custom schematic.
# Skipped when schematic_id is provided (e.g. Hetzner's public Talos ISO schematic).
resource "talos_image_factory_schematic" "this" {
  count = var.schematic_id == null ? 1 : 0

  schematic = yamlencode({
    customization = {
      extraKernelArgs = var.extra_kernel_args
      systemExtensions = {
        officialExtensions = length(var.extensions) > 0 ? data.talos_image_factory_extensions_versions.this[0].extensions_info[*].name : []
      }
    }
  })
}

# Get image URLs from the Talos image factory for the hcloud platform
data "talos_image_factory_urls" "this" {
  talos_version = var.talos_version
  schematic_id  = local.effective_schematic_id
  platform      = "hcloud"
}
