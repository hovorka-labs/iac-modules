output "mac_addresses" {
  description = "MAC address of the first network device for each VM"
  value = {
    for name, vm in proxmox_virtual_environment_vm.this :
    name => try(lower(vm.network_device[0].mac_address), null)
  }
}
