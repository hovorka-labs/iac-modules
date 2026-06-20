locals {
  gitlab_runner_values_files = (
    length(var.gitlab_runner_values_path) > 0
    ? var.gitlab_runner_values_path
    : ["${path.module}/values/values.yaml"]
  )
}

resource "helm_release" "gitlab-runner" {
  name             = "gitlab-runner"
  namespace        = "gitlab-runner"
  repository       = "http://charts.gitlab.io/"
  chart            = "gitlab-runner"
  atomic           = true
  create_namespace = true
  version          = var.chart_version
  values           = [for v in local.gitlab_runner_values_files : file(v)]

  set = [
    {
      name  = "runnerToken"
      value = var.gitlab_runner_token
    },
    {
      name  = "gitlabUrl"
      value = var.gitlab_url
    }
  ]
}
