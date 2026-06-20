output "vms" {
  value       = [for k, v in proxmox_virtual_environment_vm.this : v]
  description = "List of all proxmox_virtual_environment_vm resources"
}

output "mac_addresses" {
  description = "MAC addresses for all VMs"
  value = {
    for name, vm in proxmox_virtual_environment_vm.this :
    name => try(lower(vm.network_device[0].mac_address), null)
  }
}
