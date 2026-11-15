resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  atomic           = true
  timeout          = var.timeout
  version          = var.chart_version

  values = [for v in var.values_path : file(v)]
}
