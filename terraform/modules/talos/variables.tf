variable "cluster" {
  description = "Cluster-wide configuration shared by every node"
  type = object({
    # Talos cluster name, used for cluster registration and the generated client/kubeconfig
    name = string
    # Applied to every node as the topology.kubernetes.io/region label
    region = string
    # Explicit cluster endpoint (host[:port]); overrides vip and the first control plane node's IP
    endpoint = optional(string)

    vip                   = optional(string)
    api_server_extra_sans = optional(list(string), [])
    # Extra YAML merged into the KubeAPIServerConfig document (e.g. resources,
    # extraArgs that current Kubernetes versions still accept there). NOT the
    # right place for OIDC - current Kubernetes rejects oidc-* as a raw
    # apiserver extraArg outright; use kube_authentication_config instead.
    api_server_config = optional(string, "")
    # Kubernetes' own structured apiserver AuthenticationConfiguration
    # (apiserver.config.k8s.io), embedded as a separate KubeAuthenticationConfig
    # document. This is the only way to configure an OIDC provider (or any
    # JWT-based authenticator) on current Kubernetes - the old oidc-* apiserver
    # flags are rejected outright. Provide the full content starting at
    # `configuration:` (matching apiserver.config.k8s.io's AuthenticationConfiguration
    # shape) - see https://kubernetes.io/docs/reference/access-authn-authz/authentication/#using-authentication-configuration
    kube_authentication_config        = optional(string, "")
    allow_scheduling_on_controlplanes = optional(bool, false)
    external_cloud_provider           = optional(bool, false)
    disable_kube_proxy                = optional(bool, false)

    pod_subnets     = optional(list(string), [])
    service_subnets = optional(list(string), [])
    extra_manifests = optional(list(string), [])

    # Extra host paths bind-mounted into the kubelet's own container,
    # applied to every node. Talos's root filesystem is read-only and its
    # kubelet runs containerized, so a pod's hostPath volume needs its
    # target path mounted into the kubelet's container too, or the kubelet
    # can't propagate it into any pod at all. See the example's
    # local-path-provisioner setup for why this exists.
    kubelet_extra_mounts = optional(list(object({
      destination = string
      type        = optional(string, "bind")
      source      = string
      options     = optional(list(string), ["bind", "rshared", "rw"])
    })), [])

  })
}

variable "nodes" {
  description = "Map of nodes to configure. The map key is used as the node's identity (hostname, topology zone label unless overridden by zone)."
  type = map(object({
    # controlplane or worker
    machine_type = string
    ip           = string
    # Reach the Talos API here instead of ip, e.g. when ip is a private address behind a public one
    talos_api_ip = optional(string)

    mac_address    = optional(string, "")
    interface_name = optional(string, "")
    use_dhcp       = optional(bool, false)
    gateway        = optional(string, "")
    subnet_mask    = optional(string, "")

    installer_image_url = string
    k8s_version         = string

    # auto applies immediately and reboots if needed; staged/no_reboot/reboot are also valid, see the talos_machine_configuration_apply docs
    apply_mode = optional(string, "auto")

    # topology.kubernetes.io/zone label - defaults to the map key, but some
    # cloud integrations (e.g. Proxmox CSI/CCM) call the underlying provider
    # API using this value directly as a node identifier, so it has to match
    # the provider's own node name rather than whatever this node is called
    # in the nodes map.
    zone = optional(string)

    # Cloud controller manager node ID, in whatever URI format that CCM expects; leave unset on Proxmox, which has no CCM
    provider_id = optional(string)
    node_labels = optional(map(string), {})

    # Applied via a machine.nodeTaints patch, as { key = "value:Effect" }.
    node_taints = optional(map(string), {})
  }))

  validation {
    condition     = alltrue([for node in var.nodes : contains(["auto", "reboot", "staged", "no_reboot"], node.apply_mode)])
    error_message = "apply_mode must be one of: auto, reboot, staged, no_reboot."
  }
}
