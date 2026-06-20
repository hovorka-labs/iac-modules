# Primary cluster configuration
variable "cluster_config" {
  description = "Cluster-wide configuration settings"
  type = object({
    api_server                     = optional(string, "")       # API server configuration YAML, merged into the apiServer block (e.g. extraArgs for OIDC)
    api_server_extra_sans          = optional(list(string))     # Extra DNS names to include in the API server certificate SANs
    talos_cluster_name             = string                     # Talos cluster name
    cluster_name                   = string                     # Cluster/region name (used for topology labels)
    cluster_endpoint               = optional(string)           # Explicit cluster endpoint URL (e.g. LB IP); overrides vip and first CP IP
    external_cloud_provider        = optional(bool, false)      # Enable Kubernetes external cloud provider integration (required for cloud CCMs)
    extra_manifests                = optional(list(string), []) # Additional K8s manifests to apply
    gateway_api_version            = string                     # K8s Gateway API version
    kubelet                        = optional(string)           # Kubelet configuration YAML
    vip                            = optional(string)           # Virtual IP for control plane (keepalived)
    allowSchedulingOnControlPlanes = optional(bool, false)      # Allow scheduling on control plane nodes
    disable_kube_proxy             = optional(bool, false)      # Disable kube proxy - useful for Cilium
    pod_subnets                    = optional(list(string), []) # List of Pod CIDRs for the cluster
    service_subnets                = optional(list(string), []) # List of Service CIDRs for the cluster
  })
}

# Node-specific configurations
variable "nodes" {
  description = "Map of nodes with their configuration"
  type = map(
    object({
      dns                 = optional(list(string))    # DNS servers
      apply_mode          = string                    # Talos configuration apply mode
      recreation_hash     = string                    # Hash to trigger recreation when VM state changes
      installer_image_url = string                    # Talos installer image URL
      ip                  = string                    # Node cluster IP address
      talos_api_ip        = optional(string)          # IP used to reach the Talos API (defaults to ip); set to public IP when ip is a private address
      node_name           = string                    # Node name (used as topology zone label)
      mac_address         = optional(string, "")      # MAC address for static network config via deviceSelector
      interface_name      = optional(string, "")      # Interface name for static network config (alternative to mac_address)
      use_dhcp            = optional(bool, false)     # Use DHCP instead of static network config
      machine_type        = string                    # Node role: controlplane or worker
      provider_id         = optional(string)          # Cloud provider ID (e.g. hcloud://12345); sets kubelet --provider-id for CCM integration
      k8s_version         = string                    # Kubernetes version
      gateway             = optional(string, "")      # Network gateway IP (required when not using DHCP)
      subnet_mask         = optional(string, "")      # Network subnet mask (required when not using DHCP)
      node_labels         = optional(map(string), {}) # Extra Kubernetes node labels, merged with the topology labels (e.g. for dedicated worker pools)
      node_taints         = optional(map(string), {}) # Extra taints to self-register the node with via kubelet --register-with-taints, as { key = "value:Effect" } (e.g. { dedicated = "dev:NoSchedule" }) — NodeRestriction blocks setting these any other way for worker nodes
    })
  )
}
