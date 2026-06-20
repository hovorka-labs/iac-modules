variable "proxmox_nodes" {
  description = "List of Proxmox nodes to receive the Talos image"
  type        = list(string)
}

variable "proxmox_datastore" {
  description = "Proxmox datastore to store the ISO image"
  type        = string
  default     = "local"
}

variable "talos_version" {
  description = "Talos OS version to use (e.g., v1.9.5)"
  type        = string
}

variable "image_file_name" {
  description = "Name of the Talos image file (without extension)"
  type        = string
  default     = null
}

variable "extensions" {
  description = "List of Talos extensions to include"
  type        = list(string)
  default     = []
}

variable "extraKernelArgs" {
  description = "List of extra kernel arguments to pass to Talos"
  type        = list(string)
  default     = []
}

variable "platform" {
  description = "Platform type for the Talos image"
  type        = string
  default     = "nocloud"
}

variable "content_type" {
  description = "Content type of the Talos image file"
  type        = string
  default     = "iso"
}

variable "image_name_prefix" {
  description = "Prefix for the image file name"
  type        = string
  default     = "talos"
}