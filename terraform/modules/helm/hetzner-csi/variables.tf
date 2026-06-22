variable "chart_version" {
  description = "Version of the hcloud-csi Helm chart"
  type        = string
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token used by the CSI driver to manage block volumes"
  type        = string
  sensitive   = true
}

variable "values_path" {
  description = "List of paths to additional Helm values files"
  type        = list(string)
  default     = []
}
