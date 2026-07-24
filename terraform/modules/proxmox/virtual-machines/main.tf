resource "proxmox_virtual_environment_vm" "this" {
  for_each = var.virtual_machines

  node_name = each.value.node_name
  name      = each.key
  vm_id     = try(each.value.vm_id, null)

  description = try(each.value.description, null)
  tags        = try(each.value.tags, null)
  on_boot     = try(each.value.on_boot, true)

  machine       = try(each.value.machine, null)
  scsi_hardware = try(each.value.scsi_hardware, null)
  bios          = try(each.value.bios, null)

  agent {
    enabled = try(each.value.agent_enabled, false)
    timeout = try(each.value.agent_timeout, "15m")
  }

  cpu {
    cores = each.value.cpu.cores
    type  = try(each.value.cpu.type, null)
    flags = try(each.value.cpu.flags, [""])
    units = try(each.value.cpu.units, null)
  }

  memory {
    dedicated = each.value.memory.dedicated
    # Below dedicated, this enables ballooning (Proxmox can reclaim memory
    # under host pressure); 0 means no ballooning, memory stays pinned at
    # dedicated - the safer default for a module with no opinion on whether
    # a given VM's workload tolerates being squeezed.
    floating = try(each.value.memory.floating, 0)
  }

  dynamic "network_device" {
    for_each = try(each.value.network_devices, [])
    content {
      bridge      = network_device.value.bridge
      mac_address = try(network_device.value.mac_address, null)
      model       = try(network_device.value.model, null)
      vlan_id     = try(network_device.value.vlan_id, null)
      firewall    = try(network_device.value.firewall, false)
    }
  }

  dynamic "disk" {
    for_each = coalesce(each.value.disks, [])
    content {
      datastore_id = disk.value.datastore_id
      interface    = try(disk.value.interface, "scsi0")
      iothread     = try(disk.value.iothread, true)
      cache        = try(disk.value.cache, "writethrough")
      discard      = try(disk.value.discard, "on")
      ssd          = try(disk.value.ssd, true)
      file_format  = try(disk.value.file_format, "")
      file_id      = try(disk.value.file_id, "")
      size         = disk.value.size
    }
  }

  serial_device {
    device = try(each.value.serial_device.device, null)
  }

  # Defaults to ide3 so it doesn't collide with the cloud-init drive, which
  # Proxmox always attaches on ide2.
  cdrom {
    file_id   = try(each.value.cdrom.file_id, "none")
    interface = try(each.value.cdrom.interface, "ide3")
  }

  boot_order = try(each.value.boot_order, [])

  operating_system {
    type = try(each.value.operating_system_type, "other")
  }

  dynamic "initialization" {
    for_each = try(each.value.init, null) != null ? [each.value.init] : []
    content {
      datastore_id = initialization.value.datastore_id
      interface    = try(initialization.value.interface, null)

      dynamic "dns" {
        for_each = try(initialization.value.dns, null) != null ? { "dns" = initialization.value.dns } : {}
        content {
          servers = initialization.value.dns
        }
      }

      ip_config {
        ipv4 {
          address = initialization.value.ipv4.address
          gateway = initialization.value.ipv4.gateway
        }
      }

      dynamic "user_account" {
        for_each = try(initialization.value.auth, null) != null ? [initialization.value.auth] : []
        content {
          username = try(initialization.value.auth.username, null)
          password = try(initialization.value.auth.password, null)
          keys     = try(user_account.value.keys, null)
        }
      }
    }
  }

  dynamic "clone" {
    for_each = try(each.value.clone, null) != null ? [each.value.clone] : []
    content {
      vm_id        = clone.value.vm_id
      datastore_id = try(clone.value.datastore_id, null)
      node_name    = try(clone.value.node_name, null)
      retries      = try(clone.value.retries, null)
      full         = try(clone.value.full, true)
    }
  }

  dynamic "hostpci" {
    for_each = coalesce(try(each.value.pci_devices, []), [])
    content {
      device  = hostpci.value.device
      mapping = try(hostpci.value.mapping, null)
      pcie    = try(hostpci.value.pcie, false)
      rombar  = try(hostpci.value.rombar, false)
      xvga    = try(hostpci.value.xvga, false)
    }
  }
}
