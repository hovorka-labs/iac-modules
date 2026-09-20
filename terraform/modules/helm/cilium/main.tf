resource "kubernetes_labels" "kube_system_pod_security" {
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "kube-system"
  }
  labels = {
    "pod-security.kubernetes.io/enforce" = "privileged"
  }
}

resource "helm_release" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  atomic     = true
  timeout    = var.timeout
  version    = var.chart_version

  values = [
    for v in var.cilium_values_path : file(v)
  ]

}
