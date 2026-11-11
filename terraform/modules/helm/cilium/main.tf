resource "helm_release" "cilium" {
  name       = "cilium"
  namespace  = var.namespace
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  atomic     = true
  timeout    = var.timeout
  version    = var.chart_version

  values = [
    for v in var.cilium_values_path : file(v)
  ]

}
