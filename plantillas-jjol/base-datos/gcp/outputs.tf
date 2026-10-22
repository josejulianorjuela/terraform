output "host" {
  description = "IP privada de la instancia."
  value       = google_sql_database_instance.this.private_ip_address
}

output "port" {
  description = "Puerto de PostgreSQL."
  value       = "5432"
}

output "connection_name" {
  description = "Nombre de conexión (Cloud SQL Auth Proxy / conectores)."
  value       = google_sql_database_instance.this.connection_name
}
