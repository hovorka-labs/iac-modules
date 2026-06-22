variable "name" {
  description = "Name of the load balancer"
  type        = string
}

variable "type" {
  description = "Hetzner load balancer type (e.g. lb11, lb21, lb31)"
  type        = string
  default     = "lb11"
}

variable "location" {
  description = "Hetzner datacenter location (e.g. nbg1, fsn1, hel1)"
  type        = string
}

variable "labels" {
  description = "Labels to apply to the load balancer"
  type        = map(string)
  default     = {}
}

variable "services" {
  description = "List of services to expose on the load balancer"
  type = list(object({
    protocol         = string # tcp, http, or https
    listen_port      = number
    destination_port = number
    proxyprotocol    = optional(bool, false)
  }))
}

variable "target_label_selector" {
  description = "Hetzner label selector used to pick backend servers (e.g. 'type=controlplane,cluster=my-cluster')"
  type        = string
}

variable "use_private_ip" {
  description = "Route LB traffic to the servers' private IP instead of public IP"
  type        = bool
  default     = false
}
