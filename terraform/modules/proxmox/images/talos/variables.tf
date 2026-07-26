variable "talos_image_version" {
  description = "Talos OS version to use (e.g., v1.9.5)"
  type        = string

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.talos_image_version))
    error_message = "talos_image_version must be a semver prefixed with 'v', e.g. v1.9.5."
  }
}

variable "talos_image_extensions" {
  description = "List of Talos extensions to include"
  type        = list(string)
  default     = []
}

variable "talos_image_platform" {
  description = "Platform type for the Talos image (e.g., metal, nocloud, vmware)"
  type        = string
}

variable "proxmox_nodes" {
  description = "Proxmox nodes to download the Talos image to; defaults to all nodes in the cluster"
  type        = set(string)
  default     = null
}

variable "proxmox_datastore" {
  description = "Proxmox datastore to store the image"
  type        = string
  default     = "local"
}

variable "download_iso" {
  description = "Whether to actually download the ISO to Proxmox. The ISO is only ever used as boot media the first time a VM starts - upgrades pull the installer image directly over the network and never touch it again - so set this to false when you only need `installer_image`/`schematic_id` (e.g. to declare a new upgrade target) and aren't provisioning a new VM."
  type        = bool
  default     = true
}
