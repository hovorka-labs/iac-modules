variable "chart_version" {
  description = "Version of the hcloud-cloud-controller-manager Helm chart"
  type        = string
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Default Hetzner location for load balancers created by CCM"
  type        = string
}
