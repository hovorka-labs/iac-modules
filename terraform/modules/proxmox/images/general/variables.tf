variable "proxmox_nodes" {
  description = "List of Proxmox nodes to receive the Talos image"
  type        = list(string)
}

variable "proxmox_datastore" {
  description = "Proxmox datastore to store the ISO image"
  type        = string
}

variable "image_file_name" {
  description = "Name of the image file"
  type        = string
}

variable "image_url" {
  description = "Image URL to download the file from"
  type        = string
}

variable "content_type" {
  description = "Content type of the image file"
  type        = string
  default     = "iso"
}
