locals {
  tags   = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  labels = { for k, v in local.tags : lower(replace(k, "/[^a-zA-Z0-9_-]/", "_")) => substr(lower(replace(v, "/[^a-zA-Z0-9_-]/", "-")), 0, 63) }
  base   = "${var.name}-${var.environment}"
  # Cloud Run limita la memoria cuando la CPU es menor que 1: se usa al menos 1 vCPU.
  cpu = tostring(max(1, var.cpu))
}

# Repositorio privado con etiquetas inmutables y limpieza de versiones viejas.
resource "google_artifact_registry_repository" "this" {
  repository_id = local.base
  location      = var.region
  format        = "DOCKER"
  description   = "Imágenes de ${local.base}"

  docker_config {
    immutable_tags = true
  }

  cleanup_policies {
    id     = "conservar-recientes"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "borrar-sin-etiqueta"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "1209600s"
    }
  }
}

# Cuenta de servicio propia: nunca la predeterminada de Compute.
resource "google_service_account" "this" {
  account_id   = substr("run-${local.base}", 0, 30)
  display_name = "Cloud Run ${local.base}"
  description  = "Identidad de la aplicación ${local.base} (plantillas-jjol)."
}

resource "google_artifact_registry_repository_iam_member" "reader" {
  repository = google_artifact_registry_repository.this.name
  location   = google_artifact_registry_repository.this.location
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.this.email}"
}

resource "google_cloud_run_v2_service" "this" {
  name                = local.base
  location            = var.region
  ingress             = var.public ? "INGRESS_TRAFFIC_ALL" : "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = var.environment == "prod"

  template {
    service_account                  = google_service_account.this.email
    max_instance_request_concurrency = 80

    scaling {
      min_instance_count = var.min_replicas
      max_instance_count = var.max_replicas
    }

    containers {
      image = var.image

      ports {
        container_port = var.port
      }

      resources {
        limits = {
          cpu    = local.cpu
          memory = "${var.memory_gb}Gi"
        }
        cpu_idle = true
      }

      startup_probe {
        tcp_socket {
          port = var.port
        }
      }
    }
  }

  depends_on = [google_artifact_registry_repository_iam_member.reader]
}

# Invocación sin autenticación solo si se pide explícitamente (riesgo de seguridad alto).
resource "google_cloud_run_v2_service_iam_member" "public" {
  count    = var.allow_unauthenticated ? 1 : 0
  name     = google_cloud_run_v2_service.this.name
  location = google_cloud_run_v2_service.this.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
