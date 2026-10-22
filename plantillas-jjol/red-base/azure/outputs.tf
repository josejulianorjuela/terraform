output "network_id" {
  description = "Id de la red (VNet, VPC o VCN)."
  value       = azurerm_virtual_network.this.id
}

output "subnets" {
  description = "Subredes por nombre, en JSON."
  value       = jsonencode({ for k, s in azurerm_subnet.this : k => s.id })
}

output "resource_group_name" {
  description = "Grupo de recursos."
  value       = local.rg_name
}

output "vnet_id" {
  description = "Id de la VNet."
  value       = azurerm_virtual_network.this.id
}

output "subnet_ids" {
  description = "Ids de las subredes por nombre (app, integracion, datos, endpoints)."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}

output "nat_public_ip" {
  description = "IP pública de salida del NAT."
  value       = var.nat ? azurerm_public_ip.nat[0].ip_address : ""
}
