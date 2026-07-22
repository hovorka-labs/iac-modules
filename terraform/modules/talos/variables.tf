variable "cluster" {
  description = "Cluster-wide configuration shared by every node"
  type = object({
    name     = string           # Talos cluster name, used for cluster registration and the generated client/kubeconfig
    region   = string           # Applied to every node as the topology.kubernetes.io/region label
    endpoint = optional(string) # Explicit cluster endpoint (host[:port]); overrides vip and the first control plane node's IP

    vip                               = optional(string)
    api_server_extra_sans             = optional(list(string), [])
    api_server_config                 = optional(string, "") # Extra YAML merged into the apiServer block, e.g. extraArgs for OIDC
    allow_scheduling_on_controlplanes = optional(bool, false)
    external_cloud_provider           = optional(bool, false)
    disable_kube_proxy                = optional(bool, false)

    pod_subnets     = optional(list(string), [])
    service_subnets = optional(list(string), [])
    extra_manifests = optional(list(string), [])

    gateway_api_version = string
  })
}

variable "nodes" {
  description = "Map of nodes to configure. The map key is used as the node's topology zone label."
  type = map(object({
    machine_type = string # controlplane or worker
    ip           = string
    talos_api_ip = optional(string) # Reach the Talos API here instead of ip, e.g. when ip is a private address behind a public one (Hetzner)

    mac_address    = optional(string, "")
    interface_name = optional(string, "")
    use_dhcp       = optional(bool, false)
    gateway        = optional(string, "")
    subnet_mask    = optional(string, "")

    installer_image_url = string
    k8s_version         = string

    apply_mode = optional(string, "auto") # auto applies immediately and reboots if needed; staged/no_reboot/reboot are also valid, see the talos_machine_configuration_apply docs

    # topology.kubernetes.io/zone label - defaults to the map key, but some
    # cloud integrations (e.g. Proxmox CSI/CCM) call the underlying provider
    # API using this value directly as a node identifier, so it has to match
    # the provider's own node name rather than whatever this node is called
    # in the nodes map.
    zone = optional(string)

    provider_id = optional(string) # Cloud controller manager node ID, e.g. hcloud://12345 on Hetzner, openstack:///<uuid> on OpenStack; leave unset on Proxmox, which has no CCM
    node_labels = optional(map(string), {})

    # kubelet --register-with-taints, as { key = "value:Effect" }. NodeRestriction
    # blocks setting taints on a worker any other way after it has registered.
    node_taints = optional(map(string), {})

    # Bump to force the machine configuration to be reapplied without changing
    # any other argument, e.g. after the underlying VM has been rebuilt.
    recreation_hash = optional(string)
  }))

  validation {
    condition     = alltrue([for node in var.nodes : contains(["auto", "reboot", "staged", "no_reboot"], node.apply_mode)])
    error_message = "apply_mode must be one of: auto, reboot, staged, no_reboot."
  }
}
