variable "iso_name" {
  description = "Hetzner ISO name for the Talos boot ISO (attached for initial boot; Talos installs to disk and reboots from disk)"
  type        = string
}

variable "ssh_keys" {
  description = "List of Hetzner SSH key IDs or names to inject. Required by Hetzner even for Talos (Talos ignores them)."
  type        = list(string)
  default     = []
}

variable "servers" {
  description = "Map of server name to server configuration"
  type = map(object({
    server_type = string      # Hetzner server type (e.g. cpx21, cx32)
    location    = string      # Hetzner datacenter location (e.g. nbg1, fsn1, hel1)
    labels      = map(string) # Hetzner resource labels (used for LB target selectors)
  }))
}
