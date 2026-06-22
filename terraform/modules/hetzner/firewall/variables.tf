variable "name" {
  description = "Name of the firewall"
  type        = string
}

variable "labels" {
  description = "Labels to apply to the firewall"
  type        = map(string)
  default     = {}
}

variable "rules" {
  description = "List of firewall rules (inbound only)"
  type = list(object({
    protocol   = string           # tcp, udp, icmp, esp, gre
    port       = optional(string) # port number or range e.g. "6443" or "1-6442"; omit for icmp/esp/gre
    source_ips = list(string)     # CIDRs to allow, e.g. ["0.0.0.0/0", "::/0"]
  }))
}

variable "label_selector" {
  description = "Hetzner label selector to attach the firewall to matching servers"
  type        = string
}
