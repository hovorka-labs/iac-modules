variable "user_id" {
  description = "User ID to which the token belongs (e.g. user@pve)"
  type        = string
}

variable "token_name" {
  description = "Name of the token (e.g. tk1)"
  type        = string
}

variable "expiration_date" {
  description = "RFC3339 timestamp when the token will expire"
  type        = string
  default     = null
}

variable "comment" {
  description = "Optional comment for the token"
  type        = string
  default     = "Managed by Terraform"
}

variable "privileges_separation" {
  description = "Enable privileges separation for the token"
  type        = bool
  default     = true
}
