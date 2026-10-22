output "url" {
  description = "URL HTTPS de la aplicación."
  value       = google_cloud_run_v2_service.this.uri
}

output "registry" {
  description = "Repositorio de Artifact Registry para las imágenes."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}"
}

output "service_account" {
  description = "Cuenta de servicio de la aplicación."
  value       = google_service_account.this.email
}
