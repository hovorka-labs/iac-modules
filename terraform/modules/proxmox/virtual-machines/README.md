<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | 0.110.0 |
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.110.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
## Modules

No modules.
## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_virtual_environment_vm.this](https://registry.terraform.io/providers/bpg/proxmox/0.110.0/docs/resources/virtual_environment_vm) | resource |
| [terraform_data.vm_recreate_trigger](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_vms"></a> [vms](#input\_vms) | Map of VMs to create | <pre>map(object({<br/>    node_name       = string<br/>    recreation_hash = optional(string)<br/>    vm_id           = optional(number)<br/>    name            = optional(string)<br/>    description     = optional(string)<br/>    tags            = optional(list(string))<br/>    on_boot         = optional(bool)<br/>    machine         = optional(string)<br/>    scsi_hardware   = optional(string)<br/>    bios            = optional(string)<br/>    agent_enabled   = optional(bool)<br/><br/>    cpu = object({<br/>      cores = number<br/>      type  = optional(string)<br/>      flags = optional(list(string))<br/>      units = optional(number)<br/>    })<br/><br/>    memory = object({<br/>      dedicated = number<br/>      floating  = optional(number)<br/>    })<br/><br/>    network_devices = optional(list(object({<br/>      bridge      = string<br/>      mac_address = optional(string)<br/>      model       = optional(string)<br/>      vlan_id     = optional(string)<br/>      firewall    = optional(bool)<br/>    })))<br/><br/>    disks = optional(list(object({<br/>      datastore_id    = string<br/>      interface       = optional(string)<br/>      iothread        = optional(bool)<br/>      cache           = optional(string)<br/>      discard         = optional(string)<br/>      ssd             = optional(bool)<br/>      file_format     = optional(string)<br/>      size            = number<br/>      file_id         = optional(string)<br/>      updated_file_id = optional(string)<br/>    })))<br/><br/>    cdrom = optional(object({<br/>      file_id   = optional(string)<br/>      interface = optional(string)<br/>    }))<br/><br/>    serial_device = optional(object({<br/>      device = optional(string)<br/>    }))<br/><br/>    boot_order            = optional(list(string))<br/>    operating_system_type = optional(string)<br/><br/>    init = optional(object({<br/>      datastore_id = string<br/>      dns          = optional(list(string))<br/>      ipv4 = object({<br/>        address = string<br/>        gateway = string<br/>      })<br/>      auth = optional(object({<br/>        username          = string<br/>        password          = optional(string)<br/>        keys              = optional(list(string))<br/>        user_data_file_id = optional(string)<br/>      }))<br/>    }))<br/><br/>    clone = optional(object({<br/>      vm_id        = number<br/>      datastore_id = optional(string)<br/>      node_name    = optional(string)<br/>      retries      = optional(number)<br/>      full         = optional(bool)<br/>    }))<br/><br/>    pci_devices = optional(list(object({<br/>      device  = string<br/>      mapping = optional(string)<br/>      pcie    = optional(bool)<br/>      rombar  = optional(bool)<br/>      xvga    = optional(bool)<br/>    })))<br/>  }))</pre> | n/a | yes |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_mac_addresses"></a> [mac\_addresses](#output\_mac\_addresses) | MAC addresses for all VMs |
| <a name="output_vms"></a> [vms](#output\_vms) | List of all proxmox\_virtual\_environment\_vm resources |
<!-- END_TF_DOCS -->
