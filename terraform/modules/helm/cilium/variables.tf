variable "cilium_values_path" {
  description = "List of Cilium values paths"
  type        = list(string)
  default     = []
}

variable "chart_version" {
  description = "Cilium version to use for the cluster"
  type        = string
}

variable "timeout" {
  description = "Helm install/upgrade timeout in seconds"
  type        = number
  default     = 600
}

variable "replace_triggers" {
  description = "Values that, when changed, trigger replacement of the Helm release (e.g. cluster kubeconfig to redeploy on cluster rebuild)"
  type        = any
  default     = null
}
