variable "namespace" {
  description = "The namespace to deploy the Helm release to"
  type        = string
  default     = "openbao"
}

variable "chart_version" {
  description = "OpenBao Helm chart version to install"
  type        = string
}

variable "values_path" {
  description = "List of values file paths"
  type        = list(string)
  default     = []
}

variable "timeout" {
  description = "Helm install/upgrade timeout in seconds"
  type        = number
  default     = 600
}
