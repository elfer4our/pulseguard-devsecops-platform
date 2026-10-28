# variables.tf
variable "kubeconfig_path" {
  description = "Path to local kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubernetes context name"
  type        = string
  default     = "kind-pulseguard"
}

variable "monitoring_namespace" {
  description = "Dedicated namespace for observability stack"
  type        = string
  default     = "pulseguard-monitoring"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}
