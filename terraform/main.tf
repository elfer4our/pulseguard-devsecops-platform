terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
    }
  }

  # Production Pattern: S3 Remote Backend with DynamoDB State Locking
  # (Commented out for local execution; uncomment in AWS production)
  # backend "s3" {
  #   bucket         = "nus-devops-terraform-state-prod"
  #   key            = "pulseguard/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-locks"
  # }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
    labels = {
      managed_by = "terraform"
      environment = var.environment
    }
  }
}
