output "full_token_id" {
  description = "The full token identifier in the format user@realm!token_name"
  value       = proxmox_user_token.this.id
}

output "token_value" {
  value = split("=", proxmox_user_token.this.value)[1]
}
