variable "chart_version" {
  description = "Actions Runner Controller chart version"
  type        = string
}

variable "github_app_id" {
  description = "GitHub App ID (must be a string)"
  type        = string
  sensitive   = true
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID (must be a string)"
  type        = string
  sensitive   = true
}

variable "github_app_private_key" {
  description = "GitHub App private key in PEM format"
  type        = string
  sensitive   = true
}

variable "values_path" {
  description = "List of custom values file paths for the ARC helm chart"
  type        = list(string)
  default     = []
}

variable "replace_triggers" {
  description = "Values that, when changed, trigger replacement of the Helm release (e.g. cluster kubeconfig to redeploy on cluster rebuild)"
  type        = any
  default     = null
}
