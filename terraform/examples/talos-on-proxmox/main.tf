# Step 1: Look up a Talos OS image from the Image Factory.
#
# The module queries the Image Factory to build a schematic for the
# requested extensions and returns the installer image URL plus the ISO
# URL/expected file path - it doesn't download or upload anything itself.
# Before running Step 2 for the first time, upload the ISO to each Proxmox
# node yourself (see the module README):
#
#   name="$(tofu output -raw iso_file_name)"
#   curl -fsSL "$(tofu output -raw iso_url)" -o "$name"
#   pvesm upload <datastore> "$name" --content iso
#
# Platform is "nocloud": it's what makes Talos read the static IP we hand
# it below via cloud-init, instead of waiting on DHCP.
module "talos_image" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/images/talos?ref=proxmox-talos-images-v1.2.0"

  talos_image_version  = var.talos_version
  talos_image_platform = "nocloud"

  # Add Talos extensions required by the cluster nodes.
  # The full extension catalogue is at https://factory.talos.dev.
  talos_image_extensions = [
    "siderolabs/qemu-guest-agent",
  ]

  # Scope to specific nodes, or omit to target every node in the cluster.
  proxmox_nodes     = var.proxmox_nodes
  proxmox_datastore = var.proxmox_datastore
}

# Step 2: Provision one Proxmox VM per Talos node.
#
# Each VM boots from the image downloaded above (attached as a cdrom); the
# actual disk starts empty and Talos installs itself onto it on first boot.
# The static IP comes from cloud-init, which the nocloud platform picks up
# before Talos even has a machine config to work from.
module "vms" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/proxmox/virtual-machines?ref=proxmox-virtual-machines-v1.1.0"

  virtual_machines = local.virtual_machines
}

# Step 3: Bootstrap a Talos Kubernetes cluster on top of the VMs above.
#
# Each node's mac_address comes straight from module.vms, not a variable -
# Proxmox assigns the MAC when the VM is created, and Talos just needs to be
# told the same address so it can match the right NIC in its network config.
#
# region matters once Proxmox CSI is wired in (a future post); for now it
# just reuses the cluster name.
#
# Future step (covered in the next blog post): install Cilium. Without a
# CNI, nodes come up but nothing can actually schedule yet.
module "talos_cluster" {
  source = "git::https://github.com/hovorka-labs/iac-modules.git//terraform/modules/talos?ref=talos-v1.5.2"

  cluster = {
    name                = var.talos_cluster_name
    region              = var.talos_cluster_name
    gateway_api_version = var.gateway_api_version
  }

  nodes = local.talos_nodes
}
