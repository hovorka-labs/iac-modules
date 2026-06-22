resource "hcloud_server" "this" {
  for_each = var.servers

  name        = each.key
  server_type = each.value.server_type
  location    = each.value.location
  image       = "debian-12"  # placeholder disk — overwritten by Talos during installation
  iso         = var.iso_name # Talos ISO for initial boot; server boots from disk on subsequent reboots
  labels      = each.value.labels
  ssh_keys    = var.ssh_keys

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  lifecycle {
    # OS upgrades are handled via the Talos upgrade mechanism.
    # ISO is only needed for the very first boot.
    ignore_changes = [image, iso]
  }
}
