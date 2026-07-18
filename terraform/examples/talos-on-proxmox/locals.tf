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

  # The Talos module wants a bare IP and a separate subnet mask, not the
  # CIDR notation Proxmox's cloud-init wants above - split it once here.
  talos_nodes = {
    for name, node in var.nodes : name => {
      machine_type = node.role
      node_name    = node.proxmox_node
      ip           = split("/", node.ip)[0]
      subnet_mask  = split("/", node.ip)[1]
      gateway      = var.network_gateway

      mac_address         = module.vms.mac_addresses[name]
      installer_image_url = module.talos_image.installer_image
      k8s_version         = var.k8s_version

      # Ties Talos config re-application to the same MAC used for network
      # matching above: if the VM is ever rebuilt with a new MAC, this
      # value changes too, and the config gets reapplied to match.
      recreation_hash = module.vms.mac_addresses[name]
    }
  }
}
