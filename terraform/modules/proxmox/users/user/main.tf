resource "proxmox_virtual_environment_user" "this" {
  user_id  = var.user_id
  password = var.password
  comment  = var.comment

  dynamic "acl" {
    for_each = var.acls
    content {
      path      = acl.value.path
      propagate = lookup(acl.value, "propagate", true)
      role_id   = acl.value.role_id
    }
  }
}
