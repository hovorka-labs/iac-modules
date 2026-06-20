variable "user_id" {
  description = "Proxmox user ID (e.g., user@pve)"
  type        = string
}

variable "password" {
  description = "Password for the Proxmox user"
  type        = string
  sensitive   = true
  default     = null
}

variable "comment" {
  description = "Comment for the Proxmox user"
  type        = string
  default     = "Managed by Terraform"
}

variable "acls" {
  description = "List of ACL objects to assign to the user"
  type = list(object({
    path      = string
    role_id   = string
    propagate = optional(bool, true)
  }))
}
