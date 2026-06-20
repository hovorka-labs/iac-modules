resource "proxmox_virtual_environment_user_token" "this" {
  user_id               = var.user_id
  token_name            = var.token_name
  expiration_date       = var.expiration_date
  comment               = var.comment
  privileges_separation = var.privileges_separation
}
