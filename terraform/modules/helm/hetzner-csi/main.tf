resource "helm_release" "hetzner_csi" {
  name       = "hcloud-csi"
  namespace  = "kube-system"
  repository = "https://charts.hetzner.cloud"
  chart      = "hcloud-csi"
  version    = var.chart_version
  atomic     = true

  values = [for v in var.values_path : file(v)]

  set = [
    {
      name  = "controller.hcloudToken.value"
      value = var.hcloud_token
    }
  ]
}
