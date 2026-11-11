variable "namespace" {
  description = "The namespace to deploy the Helm release to - must already exist (e.g. created by the argocd module)"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "argocd-apps chart version to install"
  type        = string
}

variable "values_path" {
  description = "List of values file paths, defining the Application/AppProject/ApplicationSet resources to bootstrap"
  type        = list(string)
  default     = []
}

variable "timeout" {
  description = "Helm install/upgrade timeout in seconds"
  type        = number
  default     = 600
}
