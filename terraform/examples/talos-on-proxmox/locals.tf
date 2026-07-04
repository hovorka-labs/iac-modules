locals {
  # Per-role sizing. Controlplanes only run the control plane components so
  # they stay small; workers get the bulk of each host's resources.
  role_defaults = {
    controlplane = {
      cores     = 2
      memory    = 4096
      disk_size = 40
    }
    worker = {
      cores     = 4
      memory    = 8192
      disk_size = 100
    }
  }

  virtual_machines = {
    for name, node in var.nodes : name => {
      node_name = node.proxmox_node

      cpu = {
        cores = local.role_defaults[node.role].cores
      }
      memory = {
        dedicated = local.role_defaults[node.role].memory
      }

      network_devices = [
        {
          bridge = "vmbr0"
        }
      ]

      disks = [
        {
          datastore_id = var.proxmox_datastore
          size         = local.role_defaults[node.role].disk_size
        }
      ]

      cdrom = {
        file_id = module.talos_image.image_nodes[node.proxmox_node]
      }
      boot_order = ["scsi0", "ide3"]

      agent_enabled         = true
      operating_system_type = "l26"

      init = {
        datastore_id = var.proxmox_datastore
        dns          = var.network_dns_servers
        ipv4 = {
          address = node.ip
          gateway = var.network_gateway
        }
      }
    }
  }
}
