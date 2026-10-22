# Sin bloque backend: agréguelo según su entorno (archivo backend.tf o -backend-config).
terraform {
  required_version = ">= 1.8"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }
}

provider "google" {
  project        = var.project_id
  region         = var.region
  default_labels = local.labels
}
