resource "hcloud_load_balancer" "this" {
  name               = var.name
  load_balancer_type = var.type
  location           = var.location
  labels             = var.labels
}

resource "hcloud_load_balancer_service" "this" {
  for_each = { for svc in var.services : tostring(svc.listen_port) => svc }

  load_balancer_id = hcloud_load_balancer.this.id
  protocol         = each.value.protocol
  listen_port      = each.value.listen_port
  destination_port = each.value.destination_port
  proxyprotocol    = each.value.proxyprotocol
}

resource "hcloud_load_balancer_target" "this" {
  type             = "label_selector"
  load_balancer_id = hcloud_load_balancer.this.id
  label_selector   = var.target_label_selector
  use_private_ip   = var.use_private_ip

  depends_on = [hcloud_load_balancer_service.this]
}
