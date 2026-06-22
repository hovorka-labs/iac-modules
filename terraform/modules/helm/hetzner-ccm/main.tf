resource "helm_release" "hetzner_ccm" {
  name       = "hcloud-cloud-controller-manager"
  namespace  = "kube-system"
  repository = "https://charts.hetzner.cloud"
  chart      = "hcloud-cloud-controller-manager"
  version    = var.chart_version
  atomic     = true

  values = [yamlencode({
    # Pod routing is handled by Cilium — disable Hetzner route management
    networking = {
      enabled = false
    }
    env = {
      # The chart defaults HCLOUD_TOKEN to valueFrom.secretKeyRef. Setting valueFrom=null
      # clears that default via Helm's null-merge behaviour so only `value` is rendered.
      HCLOUD_TOKEN = {
        value     = var.hcloud_token
        valueFrom = null
      }
      # Disable CCM-managed LBs — floating IP + FIP controller handles ingress instead
      HCLOUD_LOAD_BALANCERS_ENABLED = {
        value = "false"
      }
      HCLOUD_LOAD_BALANCERS_LOCATION = {
        value = var.location
      }
    }
  })]
}
