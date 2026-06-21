variable "namespace" {
  description = "Namespace where the runner deployment will be created"
  type        = string
  default     = "github-runners"
}

variable "github_org" {
  description = "GitHub organization name for the runner"
  type        = string
}

variable "runner_replicas" {
  description = "Number of runner replicas"
  type        = number
  default     = 1
}

variable "runner_labels" {
  description = "Labels for the runner"
  type        = list(string)
  default     = ["self-hosted", "linux"]
}

variable "deploy_namespaces" {
  description = "Namespaces the runner is allowed to deploy to (creates namespace-scoped RBAC)"
  type        = list(string)
  default     = []
}

variable "replace_triggers" {
  description = "Values that, when changed, trigger replacement of the Helm release (e.g. cluster kubeconfig to redeploy on cluster rebuild)"
  type        = any
  default     = null
}
