resource "kubernetes_labels" "csi_proxmox_pod_security" {
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "csi-proxmox"
  }
  labels = {
    "pod-security.kubernetes.io/enforce" = "privileged"
  }
  depends_on = [helm_release.proxmox_csi_plugin]
}

resource "helm_release" "proxmox_csi_plugin" {
  name             = "proxmox-csi-plugin"
  namespace        = "csi-proxmox"
  repository       = "oci://ghcr.io/sergelogvinov/charts"
  chart            = "proxmox-csi-plugin"
  create_namespace = true
  atomic           = true
  version          = var.chart_version

  values = concat(
    [for v in var.values_path : file(v)],
    [yamlencode({
      config = {
        clusters = [{
          url          = var.proxmox_url
          insecure     = var.proxmox_insecure
          token_id     = var.proxmox_token_id
          token_secret = var.proxmox_token_secret
          region       = var.proxmox_region
        }]
      }
    })]
  )

}
