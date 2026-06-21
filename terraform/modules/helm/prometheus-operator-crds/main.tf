resource "terraform_data" "replace_trigger" {
  triggers_replace = var.replace_triggers
}

resource "helm_release" "prometheus_crds" {
  name       = "prometheus-operator-crds"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-operator-crds"
  atomic     = true
  version    = var.chart_version
  namespace  = "default"

  lifecycle {
    replace_triggered_by = [terraform_data.replace_trigger]
  }
}
