resource "proxmox_virtual_environment_user" "this" {
  user_id  = var.user_id
  password = var.password
  comment  = var.comment
}

resource "proxmox_acl" "this" {
  for_each = { for i, acl in var.acls : i => acl }

  user_id   = proxmox_virtual_environment_user.this.user_id
  path      = each.value.path
  role_id   = each.value.role_id
  propagate = each.value.propagate
}
