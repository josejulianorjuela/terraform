output "host" {
  description = "Nombre DNS privado del servidor."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "port" {
  description = "Puerto de PostgreSQL."
  value       = "5432"
}

output "admin" {
  description = "Administrador de Entra ID del servidor."
  value       = var.entra_admin_name
}
