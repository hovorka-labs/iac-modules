# OpenBao boots sealed and has no way to become healthy on its own: its
# readiness probe won't pass until a human runs scripts/openbao.sh to
# initialize and unseal it. Every other helm_release in this repo can safely
# wait on rollout because nothing else here needs a manual, out-of-band step
# first - this is the one exception, so wait/atomic are deliberately off
# rather than exposed as variables, to keep that exception visible here
# rather than something a caller could silently flip.
resource "helm_release" "openbao" {
  name             = "openbao"
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://openbao.github.io/openbao-helm"
  chart            = "openbao"
  version          = var.chart_version
  timeout          = var.timeout
  wait             = false
  atomic           = false

  values = [for v in var.values_path : file(v)]
}
