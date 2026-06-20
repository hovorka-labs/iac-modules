variable "cilium_values_path" {
  description = "List of Cilium values paths"
  type        = list(string)
  default     = []
}

variable "chart_version" {
  description = "Cilium version to use for the cluster"
  type        = string
}
