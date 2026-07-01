resource "proxmox_virtual_environment_vm" "this" {
  for_each = var.virtual_machines

  # Identification
  name      = each.value.name
  vm_id     = each.value.vm_id
  node_name = each.value.node_name



}
