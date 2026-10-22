output "function_name" {
  description = "Nombre de la función."
  value       = google_cloudfunctions2_function.this.name
}

output "queue" {
  description = "Tema de Pub/Sub que dispara la función."
  value       = google_pubsub_topic.this.id
}

output "url" {
  description = "URL interna de la función."
  value       = google_cloudfunctions2_function.this.url
}
