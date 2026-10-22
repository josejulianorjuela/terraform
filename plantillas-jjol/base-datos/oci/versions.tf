# Sin bloque backend: agréguelo según su entorno (archivo backend.tf o -backend-config).
terraform {
  required_version = ">= 1.8"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.0"
    }
  }
}

# Autenticación por variables de entorno (TF_VAR_/OCI_*) o ~/.oci/config del runner.
provider "oci" {
  region = var.region
}
