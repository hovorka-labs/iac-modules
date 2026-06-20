output "kubeconfig" {
  description = "Kubeconfig for accessing the Kubernetes cluster"
  value       = module.talos_cluster.kubeconfig
  sensitive   = true
}

output "talosconfig" {
  description = "Talosconfig for accessing the Talos nodes via talosctl"
  value       = module.talos_cluster.talosconfig
  sensitive   = true
}

output "cluster_name" {
  description = "Name of the Talos cluster"
  value       = local.cluster_name
}
