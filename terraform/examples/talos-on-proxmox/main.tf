# Step 1: Download Talos OS images to Proxmox nodes.
#
# The module queries the Talos Image Factory to build a schematic for the
# requested extensions, then downloads the resulting ISO to every node so
# VMs can be created from it regardless of which node they land on.
#
# Future steps (covered in upcoming blog posts):
#   Step 2 - Generate Talos machine secrets and per-node configs
#   Step 3 - Provision Proxmox VMs using the downloaded image
#   Step 4 - Bootstrap the Talos / Kubernetes cluster
module "talos_image" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/images/talos?ref=proxmox-talos-images-v1.0.0"

  talos_image_version  = var.talos_version
  talos_image_platform = "metal"

  # Add Talos extensions required by the cluster nodes.
  # The full extension catalogue is at https://factory.talos.dev.
  talos_image_extensions = [
    "siderolabs/qemu-guest-agent",
  ]

  # Scope the download to specific nodes, or omit to target every node.
  proxmox_nodes     = var.proxmox_nodes
  proxmox_datastore = var.proxmox_datastore
}
