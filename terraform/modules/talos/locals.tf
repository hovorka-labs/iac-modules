locals {
  control_plane_nodes = { for name, node in var.nodes : name => node if node.machine_type == "controlplane" }

  first_control_plane_name = keys(local.control_plane_nodes)[0]

  # Talos API endpoint per node — defaults to the cluster IP, but can be
  # overridden when it isn't directly reachable, e.g. a private IP behind a
  # public one on Hetzner.
  talos_api_ips = {
    for name, node in var.nodes : name => coalesce(node.talos_api_ip, node.ip)
  }

  first_control_plane_api_ip = local.talos_api_ips[local.first_control_plane_name]

  control_plane_ips = [for name, ip in local.talos_api_ips : ip if var.nodes[name].machine_type == "controlplane"]
  worker_ips        = [for name, ip in local.talos_api_ips : ip if var.nodes[name].machine_type == "worker"]

  # Upgrade order: control planes first (so etcd quorum is never put at risk
  # by two control planes rebooting at once), then workers, each sorted for
  # a stable, deterministic sequence across plans. terraform_data.upgrade's
  # own script loops over this list one node at a time, gating each step on
  # the whole cluster reporting healthy again before moving to the next.
  upgrade_order = concat(
    sort([for name, node in var.nodes : name if node.machine_type == "controlplane"]),
    sort([for name, node in var.nodes : name if node.machine_type == "worker"])
  )

  # Endpoint baked into every machine config: an explicit override wins, then
  # the VIP, then just the first control plane node's IP.
  cluster_endpoint = coalesce(
    var.cluster.endpoint,
    var.cluster.vip,
    local.control_plane_nodes[local.first_control_plane_name].ip
  )

  # provider-id identifies the node to a cloud controller manager - any of
  # them, not just Hetzner's (hcloud://<id>); irrelevant without one, e.g. on Proxmox.
  #
  # register-with-taints is for dedicated worker pools and applies everywhere.
  # NodeRestriction forbids a kubelet from changing its own node's taints
  # after registration (a machine.nodeTaints patch gets rejected), so setting
  # them at kubelet startup is the only mechanism that reliably works.
  kubelet_extra_args = {
    for name, node in var.nodes : name => merge(
      node.provider_id != null ? { "provider-id" = node.provider_id } : {},
      length(node.node_taints) > 0 ? {
        "register-with-taints" = join(",", [for k, v in node.node_taints : "${k}=${v}"])
      } : {}
    )
  }

  # Applied before Kubernetes even exists, so anything that needs these CRDs
  # during cluster bootstrap doesn't hit a chicken-and-egg problem waiting on
  # them.
  gateway_api_manifests = [
    "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.cluster.gateway_api_version}/standard-install.yaml",
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${var.cluster.gateway_api_version}/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml",
  ]

  node_config_patches = {
    for name, node in var.nodes : name => concat(
      [
        templatefile("${path.module}/templates/machine-config/common.yaml.tftpl", {
          hostname            = name
          zone                = coalesce(node.zone, name)
          region              = var.cluster.region
          k8s_version         = node.k8s_version
          installer_image_url = node.installer_image_url
          machine_type        = node.machine_type
          disable_kube_proxy  = var.cluster.disable_kube_proxy
          node_labels         = node.node_labels
          pod_subnets         = var.cluster.pod_subnets
          service_subnets     = var.cluster.service_subnets
        })
      ],
      length(local.kubelet_extra_args[name]) > 0 ? [
        yamlencode({
          machine = {
            kubelet = {
              extraArgs = local.kubelet_extra_args[name]
            }
          }
        })
      ] : [],
      node.machine_type == "controlplane" ? [
        templatefile("${path.module}/templates/machine-config/control-plane.yaml.tftpl", {
          vip                               = var.cluster.vip
          api_server_extra_sans             = var.cluster.api_server_extra_sans
          api_server_config                 = var.cluster.api_server_config
          allow_scheduling_on_controlplanes = var.cluster.allow_scheduling_on_controlplanes
          external_cloud_provider           = var.cluster.external_cloud_provider
          extra_manifests                   = jsonencode(concat(var.cluster.extra_manifests, local.gateway_api_manifests))
          ip                                = node.ip
          mac_address                       = lower(node.mac_address)
          interface_name                    = node.interface_name
          use_dhcp                          = node.use_dhcp
          gateway                           = node.gateway
          subnet_mask                       = node.subnet_mask
        })
        ] : [
        templatefile("${path.module}/templates/machine-config/worker.yaml.tftpl", {
          ip             = node.ip
          mac_address    = lower(node.mac_address)
          interface_name = node.interface_name
          use_dhcp       = node.use_dhcp
          gateway        = node.gateway
          subnet_mask    = node.subnet_mask
        })
      ]
    )
  }
}
