# The documented, narrow exception to this repo's "no kubernetes_manifest/
# kubectl_manifest, everything is a helm_release" rule. Prefer an upstream
# chart's own values schema first - this module exists only for manifests
# that have no chart at all, or that would race a chart's own CRDs/webhook
# if applied as part of the same release (see callers for which applies).
resource "helm_release" "raw_manifests" {
  name             = var.release_name
  namespace        = var.namespace
  create_namespace = var.create_namespace
  chart            = "${path.module}/chart"
  atomic           = true
  timeout          = var.timeout

  values = [yamlencode({ manifests = var.manifests })]
}
