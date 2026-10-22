output "url" {
  description = "URL pública (si hay Ingress) o dirección interna del servicio."
  value       = var.ingress_host != "" ? "https://${var.ingress_host}" : "http://${kubernetes_service_v1.this.metadata[0].name}.${local.ns}.svc.cluster.local"
}

output "namespace" {
  description = "Namespace de la aplicación."
  value       = local.ns
}

output "service" {
  description = "Servicio interno."
  value       = kubernetes_service_v1.this.metadata[0].name
}
