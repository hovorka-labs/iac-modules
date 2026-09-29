variable "role_id" {
  description = "The ID of the Proxmox role"
  type        = string
}

variable "privileges" {
  description = "List of privileges for the role"
  type        = list(string)
}
