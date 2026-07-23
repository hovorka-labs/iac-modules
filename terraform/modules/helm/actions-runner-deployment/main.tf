resource "helm_release" "runner_deployment" {
  name             = "github-runner"
  namespace        = var.namespace
  create_namespace = true
  chart            = "${path.module}/templates/runner-deployment"

  # actions-runner-controller's admission webhook can still be a few seconds
  # from routable right after the controller release reports deployed (its
  # Service's endpoints haven't propagated yet), so a RunnerDeployment
  # created immediately after can hit a webhook timeout. atomic makes that
  # failure self-healing - Helm rolls the release back instead of leaving a
  # failed release behind, so a plain retry succeeds instead of needing a
  # manual helm uninstall first.
  atomic = true

  values = [yamlencode({
    name             = "github-runner"
    organization     = var.github_org
    replicas         = var.runner_replicas
    labels           = var.runner_labels
    dockerEnabled    = false
    deployNamespaces = var.deploy_namespaces
  })]

}
