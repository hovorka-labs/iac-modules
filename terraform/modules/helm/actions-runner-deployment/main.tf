resource "terraform_data" "replace_trigger" {
  triggers_replace = var.replace_triggers
}

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

  lifecycle {
    replace_triggered_by = [terraform_data.replace_trigger]
  }
}
