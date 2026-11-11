resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  atomic           = true
  timeout          = var.timeout
  version          = var.chart_version

  values = [
    for v in var.values_path : file(v)
  ]
}
