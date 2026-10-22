output "url" {
  description = "URL HTTPS de la aplicación."
  value       = "https://${azurerm_container_app.this.ingress[0].fqdn}"
}

output "registry" {
  description = "Servidor del registro de contenedores."
  value       = azurerm_container_registry.this.login_server
}

output "identity_client_id" {
  description = "Client id de la identidad administrada de la aplicación."
  value       = azurerm_user_assigned_identity.this.client_id
}
