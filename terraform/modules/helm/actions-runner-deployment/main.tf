resource "helm_release" "runner_deployment" {
  name             = "github-runner"
  namespace        = var.namespace
  create_namespace = true
  chart            = "${path.module}/templates/runner-deployment"

  values = [yamlencode({
    name             = "github-runner"
    organization     = var.github_org
    replicas         = var.runner_replicas
    labels           = var.runner_labels
    dockerEnabled    = false
    deployNamespaces = var.deploy_namespaces
  })]
}
