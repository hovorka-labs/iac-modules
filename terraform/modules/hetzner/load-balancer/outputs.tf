output "id" {
  description = "Load balancer ID"
  value       = hcloud_load_balancer.this.id
}

output "ipv4" {
  description = "Public IPv4 address of the load balancer"
  value       = hcloud_load_balancer.this.ipv4
}

output "ipv6" {
  description = "Public IPv6 address of the load balancer"
  value       = hcloud_load_balancer.this.ipv6
}
