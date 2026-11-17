variable "namespace" {
  description = "The namespace to deploy the Helm chart to"
  type        = string
  default     = "argocd"
}

variable "values_path" {
  description = "List of ArgoCD values paths"
  type        = list(string)
  default     = []
}

variable "chart_version" {
  description = "argo-cd chart version to use"
  type        = string
}

variable "timeout" {
  description = "Helm install/upgrade timeout in seconds"
  type        = number
  default     = 600
}
