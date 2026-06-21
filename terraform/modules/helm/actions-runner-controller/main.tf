locals {
  values_files = (
    length(var.values_path) > 0
    ? var.values_path
    : ["${path.module}/values/values.yaml"]
  )
}

resource "helm_release" "actions_runner_controller" {
  name             = "actions-runner-controller"
  namespace        = "actions-runner-system"
  repository       = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart            = "actions-runner-controller"
  atomic           = true
  create_namespace = true
  version          = var.chart_version
  values           = [for v in local.values_files : file(v)]

  set_sensitive = [
    {
      name  = "authSecret.github_app_id"
      value = var.github_app_id
    },
    {
      name  = "authSecret.github_app_installation_id"
      value = var.github_app_installation_id
    },
    {
      name  = "authSecret.github_app_private_key"
      value = var.github_app_private_key
    }
  ]

}
