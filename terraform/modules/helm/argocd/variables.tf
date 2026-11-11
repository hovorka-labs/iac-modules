variable "namespace" {
  description = "The namespace to deploy the Helm chart to"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "ArgoCD chart version to install"
  type        = string
}

variable "values_path" {
  description = "List of ArgoCD values file paths. Values are applied against the upstream argo-cd chart directly (no wrapper chart nesting)"
  type        = list(string)
  default     = []
}

variable "timeout" {
  description = "Helm install/upgrade timeout in seconds"
  type        = number
  default     = 600
}
