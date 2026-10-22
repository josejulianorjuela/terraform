output "function_name" {
  description = "Nombre de la Function App."
  value       = azurerm_function_app_flex_consumption.this.name
}

output "queue" {
  description = "Cola que dispara la función."
  value       = "${azurerm_storage_account.this.name}/${azurerm_storage_queue.this.name}"
}

output "url" {
  description = "URL de la Function App (acceso solo por la red privada)."
  value       = "https://${azurerm_function_app_flex_consumption.this.default_hostname}"
}
