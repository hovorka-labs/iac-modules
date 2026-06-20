locals {
  # Generate file name if not provided
  generated_file_name = "${var.image_name_prefix}-${var.talos_version}-${talos_image_factory_schematic.this.id}-${var.platform}"

  # Use provided name or generated one
  file_name = "${coalesce(var.image_file_name, local.generated_file_name)}.${var.content_type}"
}

# Get Talos extensions versions compatible with our Talos version
data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  filters = {
    names = var.extensions
  }
}

# Create a schematic with requested extensions
resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      extraKernelArgs = var.extraKernelArgs
      systemExtensions = {
        officialExtensions = length(var.extensions) > 0 ? data.talos_image_factory_extensions_versions.this.extensions_info[*].name : []
      }
    }
  })
}

# Get URLs for the Talos images
data "talos_image_factory_urls" "this" {
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = var.platform
}

# Download the image file to each Proxmox node
resource "proxmox_virtual_environment_download_file" "this" {
  for_each = toset(var.proxmox_nodes)

  node_name           = each.key
  content_type        = var.content_type
  datastore_id        = var.proxmox_datastore
  overwrite_unmanaged = true
  overwrite           = false

  file_name = local.file_name
  url       = data.talos_image_factory_urls.this.urls[var.content_type]
}
