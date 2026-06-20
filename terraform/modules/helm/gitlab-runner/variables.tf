variable "gitlab_runner_values_path" {
  description = "List of Gitlab Runner values paths"
  type        = list(string)
  default     = []
}

variable "gitlab_runner_token" {
  description = "Registration token for the GitLab Runner"
  type        = string
  sensitive   = true
  default     = ""
}

variable "gitlab_url" {
  description = "URL of the GitLab instance"
  type        = string
  default     = "https://gitlab.com"
}

variable "chart_version" {
  description = "GitLab Runner version to use for the cluster"
  type        = string
}