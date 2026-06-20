variable "vms" {
  description = "Map of VMs to create"
  type = map(object({
    node_name       = string
    recreation_hash = optional(string)
    vm_id           = optional(number)
    name            = optional(string)
    description     = optional(string)
    tags            = optional(list(string))
    on_boot         = optional(bool)
    machine         = optional(string)
    scsi_hardware   = optional(string)
    bios            = optional(string)
    agent_enabled   = optional(bool)

    cpu = object({
      cores = number
      type  = optional(string)
      flags = optional(list(string))
      units = optional(number)
    })

    memory = object({
      dedicated = number
      floating  = optional(number)
    })

    network_devices = optional(list(object({
      bridge      = string
      mac_address = optional(string)
      model       = optional(string)
      vlan_id     = optional(string)
      firewall    = optional(bool)
    })))

    disks = optional(list(object({
      datastore_id    = string
      interface       = optional(string)
      iothread        = optional(bool)
      cache           = optional(string)
      discard         = optional(string)
      ssd             = optional(bool)
      file_format     = optional(string)
      size            = number
      file_id         = optional(string)
      updated_file_id = optional(string)
    })))

    cdrom = optional(object({
      file_id   = optional(string)
      interface = optional(string)
    }))

    serial_device = optional(object({
      device = optional(string)
    }))

    boot_order            = optional(list(string))
    operating_system_type = optional(string)

    init = optional(object({
      datastore_id = string
      dns          = optional(list(string))
      ipv4 = object({
        address = string
        gateway = string
      })
      auth = optional(object({
        username          = string
        password          = optional(string)
        keys              = optional(list(string))
        user_data_file_id = optional(string)
      }))
    }))

    clone = optional(object({
      vm_id        = number
      datastore_id = optional(string)
      node_name    = optional(string)
      retries      = optional(number)
      full         = optional(bool)
    }))

    pci_devices = optional(list(object({
      device  = string
      mapping = optional(string)
      pcie    = optional(bool)
      rombar  = optional(bool)
      xvga    = optional(bool)
    })))
  }))
}
