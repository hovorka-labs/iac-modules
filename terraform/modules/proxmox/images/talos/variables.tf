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
