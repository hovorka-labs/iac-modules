variable "chart_version" {
  description = "Prometheus Operator CRDs chart version"
  type        = string
}

variable "replace_triggers" {
  description = "Values that, when changed, trigger replacement of the Helm release (e.g. cluster kubeconfig to redeploy on cluster rebuild)"
  type        = any
  default     = null
}
