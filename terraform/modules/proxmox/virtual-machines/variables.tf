variable "virtual_machines" {
  description = "Map of VMs to create. Map key becomes the VM name."
  type = map(object({
    node_name   = string
    vm_id       = optional(number)
    description = optional(string)
    tags        = optional(list(string))
    on_boot     = optional(bool)

    machine       = optional(string)
    scsi_hardware = optional(string)
    bios          = optional(string)

    # Requires the QEMU guest agent running inside the guest OS, otherwise
    # Terraform just waits out `agent_timeout` on every apply.
    agent_enabled = optional(bool)
    agent_timeout = optional(string)

    cpu = object({
      cores = number
      type  = optional(string)
      flags = optional(list(string))
      units = optional(number)
    })

    memory = object({
      dedicated = number
      # enables memory ballooning
      floating = optional(number)
    })

    network_devices = optional(list(object({
      bridge      = string
      mac_address = optional(string)
      model       = optional(string)
      vlan_id     = optional(string)
      firewall    = optional(bool)
    })))

    disks = optional(list(object({
      datastore_id = string
      interface    = optional(string)
      iothread     = optional(bool)
      cache        = optional(string)
      discard      = optional(string)
      ssd          = optional(bool)
      file_format  = optional(string)
      size         = number
      # source image/template to clone from
      file_id = optional(string)
    })))

    # Defaults to ide3: ide2 is reserved for the cloud-init drive below.
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
        username = string
        password = optional(string)
        keys     = optional(list(string))
      }))
    }))

    # Clones this VM from an existing template instead of building it fresh.
    clone = optional(object({
      vm_id        = number
      datastore_id = optional(string)
      node_name    = optional(string)
      retries      = optional(number)
      full         = optional(bool)
    }))

    # PCI/GPU passthrough. `mapping` refers to a resource mapping configured
    # under Datacenter > Resource Mappings in Proxmox.
    pci_devices = optional(list(object({
      device  = string
      mapping = optional(string)
      pcie    = optional(bool)
      rombar  = optional(bool)
      xvga    = optional(bool)
    })))
  }))
}
