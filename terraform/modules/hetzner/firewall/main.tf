resource "hcloud_firewall" "this" {
  name   = var.name
  labels = var.labels

  dynamic "rule" {
    for_each = var.rules
    content {
      direction  = "in"
      protocol   = rule.value.protocol
      port       = rule.value.port
      source_ips = rule.value.source_ips
    }
  }
}

resource "hcloud_firewall_attachment" "this" {
  firewall_id     = hcloud_firewall.this.id
  label_selectors = [var.label_selector]
}
