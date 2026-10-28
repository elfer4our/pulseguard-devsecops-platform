# outputs.tf
output "provisioned_namespace" {
  description = "The Kubernetes namespace managed by Terraform"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}
