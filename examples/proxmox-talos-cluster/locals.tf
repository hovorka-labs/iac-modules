locals {
  # Cluster identity
  cluster_name         = "my-talos-cluster"
  proxmox_cluster_name = "my-proxmox-cluster"

  # Version configuration
  # During upgrades, set the upgraded_* versions to the target version,
  # then flip upgrade_talos / upgrade_k8s per node (see README.md).
  talos_version          = "v1.12.0"
  upgraded_talos_version = "v1.12.0"
  k8s_version            = "v1.33.3"
  upgraded_k8s_version   = "v1.33.3"
  gateway_api_version    = "v1.3.0"

  # Proxmox nodes and storage
  proxmox_nodes         = ["pve-01", "pve-02", "pve-03"]
  proxmox_datastore_iso = "local"
  proxmox_datastore_vm  = "local-lvm"

  # Talos image extensions
  talos_extensions = [
    "i915-ucode",
    "intel-ucode",
    "qemu-guest-agent",
  ]

  # Network
  network = {
    gateway         = "10.0.0.1"
    subnet_mask     = "24"
    dns_servers     = ["1.1.1.1", "8.8.8.8"]
    vip             = "10.0.0.100"
    pod_subnets     = ["10.244.0.0/16"]
    service_subnets = ["10.96.0.0/12"]
  }

  # VM defaults shared by all nodes
  vm_defaults = {
    scsi_hardware         = "virtio-scsi-single"
    bios                  = "seabios"
    agent_enabled         = true
    machine               = "q35"
    operating_system_type = "l26"
    network_devices = [
      {
        bridge = "vmbr0"
        model  = "virtio"
      },
    ]
  }

  # Role-based sizing
  node_configs = {
    controlplane = {
      cpu       = { cores = 2 }
      memory    = { dedicated = 4096, floating = 4096 }
      disk_size = 40
    }
    worker = {
      cpu       = { cores = 4 }
      memory    = { dedicated = 12288, floating = 12288 }
      disk_size = 100
    }
  }

  # Node definitions
  # upgrade_talos: when true, the node uses upgraded_talos_version (VM gets recreated)
  # upgrade_k8s:   when true, the node uses upgraded_k8s_version (in-place, no recreation)
  nodes = {
    "cp-01" = {
      machine_type  = "controlplane"
      ip            = "10.0.0.101"
      proxmox_node  = "pve-01"
      upgrade_talos = false
      upgrade_k8s   = false
    }
    "cp-02" = {
      machine_type  = "controlplane"
      ip            = "10.0.0.102"
      proxmox_node  = "pve-02"
      upgrade_talos = false
      upgrade_k8s   = false
    }
    "cp-03" = {
      machine_type  = "controlplane"
      ip            = "10.0.0.103"
      proxmox_node  = "pve-03"
      upgrade_talos = false
      upgrade_k8s   = false
    }
    "worker-01" = {
      machine_type  = "worker"
      ip            = "10.0.0.111"
      proxmox_node  = "pve-01"
      upgrade_talos = false
      upgrade_k8s   = false
    }
    "worker-02" = {
      machine_type  = "worker"
      ip            = "10.0.0.112"
      proxmox_node  = "pve-02"
      upgrade_talos = false
      upgrade_k8s   = false
    }
    "worker-03" = {
      machine_type  = "worker"
      ip            = "10.0.0.113"
      proxmox_node  = "pve-03"
      upgrade_talos = false
      upgrade_k8s   = false
    }
  }

  # Compose the final VM map — merges defaults, role config, and per-node settings
  proxmox_vms = {
    for name, config in local.nodes : name => merge(
      local.vm_defaults,
      local.node_configs[config.machine_type],
      {
        node_name = config.proxmox_node

        init = {
          datastore_id = local.proxmox_datastore_vm
          dns          = local.network.dns_servers
          ipv4 = {
            address = "${config.ip}/${local.network.subnet_mask}"
            gateway = local.network.gateway
          }
        }

        disks = [
          {
            datastore_id = local.proxmox_datastore_vm
            size         = local.node_configs[config.machine_type].disk_size
            interface    = "scsi0"
          },
        ]

        cdrom = {
          file_id   = config.upgrade_talos ? module.upgraded_talos_image.image_nodes[config.proxmox_node] : module.talos_image.image_nodes[config.proxmox_node]
          interface = "ide1"
        }

        boot_order = ["scsi0", "ide1"]
        recreation_hash = md5(jsonencode({
          image = config.upgrade_talos ? module.upgraded_talos_image.image_nodes[config.proxmox_node] : module.talos_image.image_nodes[config.proxmox_node]
        }))
        tags = ["provisioned-by-terraform", "talos"]
      },
    )
  }

  # Compose the Talos node map consumed by the talos module
  talos_nodes = {
    for name, config in local.nodes : name => {
      machine_type        = config.machine_type
      node_name           = config.proxmox_node
      ip                  = config.ip
      mac_address         = module.vms.mac_addresses[name]
      gateway             = local.network.gateway
      subnet_mask         = local.network.subnet_mask
      installer_image_url = config.upgrade_talos ? module.upgraded_talos_image.installer_image_url : module.talos_image.installer_image_url
      k8s_version         = config.upgrade_k8s ? local.upgraded_k8s_version : local.k8s_version
      apply_mode          = "auto"
      recreation_hash = md5(jsonencode({
        image       = config.upgrade_talos ? module.upgraded_talos_image.image_nodes[config.proxmox_node] : module.talos_image.image_nodes[config.proxmox_node]
        k8s_version = config.upgrade_k8s ? local.upgraded_k8s_version : local.k8s_version
      }))
    }
  }

  # Parse kubeconfig for Helm/Kubernetes providers
  kubeconfig_parsed = yamldecode(module.talos_cluster.kubeconfig)
  kubeconfig_data = {
    host                   = local.kubeconfig_parsed.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kubeconfig_parsed.clusters[0].cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.kubeconfig_parsed.users[0].user["client-certificate-data"])
    client_key             = base64decode(local.kubeconfig_parsed.users[0].user["client-key-data"])
  }
}
