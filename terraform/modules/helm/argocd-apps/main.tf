resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  atomic     = true
  timeout    = var.timeout
  version    = var.chart_version

  values = [
    for v in var.values_path : file(v)
  ]
}
