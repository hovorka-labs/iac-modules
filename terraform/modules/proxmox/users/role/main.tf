resource "proxmox_virtual_environment_role" "this" {
  role_id = var.role_id

  privileges = var.privileges
}
