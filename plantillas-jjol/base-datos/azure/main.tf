locals {
  tags    = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  base    = "${var.name}-${var.environment}"
  rg_name = var.resource_group_name != "" ? var.resource_group_name : azurerm_resource_group.this[0].name
  suffix  = substr(sha1("${var.subscription_id}/${local.base}"), 0, 6)
  # La alta disponibilidad con zonas exige General Purpose; sin ella, Burstable basta para 2 vCPU.
  sku     = var.ha || var.cpu > 2 ? "GP_Standard_D${var.cpu}ds_v5" : "B_Standard_B${var.cpu}ms"
  vnet_id = split("/subnets/", var.subnet_id)[0]
  dns_id  = var.private_dns_zone_id != "" ? var.private_dns_zone_id : azurerm_private_dns_zone.this[0].id
  admin   = var.entra_admin_object_id != "" ? var.entra_admin_object_id : data.azurerm_client_config.current.object_id
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  count    = var.resource_group_name == "" ? 1 : 0
  name     = "rg-${local.base}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_private_dns_zone" "this" {
  count               = var.private_dns_zone_id == "" ? 1 : 0
  name                = "${local.base}-${local.suffix}.private.postgres.database.azure.com"
  resource_group_name = local.rg_name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  count                = var.private_dns_zone_id == "" ? 1 : 0
  name                 = "link-${local.base}"
  private_dns_zone_id  = azurerm_private_dns_zone.this[0].id
  virtual_network_id   = local.vnet_id
  registration_enabled = false
  tags                 = local.tags
}

# Servidor privado (integración con VNet), solo autenticación de Entra ID, TLS obligatorio por defecto.
resource "azurerm_postgresql_flexible_server" "this" {
  name                          = "psql-${local.base}-${local.suffix}"
  location                      = var.location
  resource_group_name           = local.rg_name
  version                       = var.postgres_version
  sku_name                      = local.sku
  storage_mb                    = var.storage_gb * 1024
  auto_grow_enabled             = true
  backup_retention_days         = var.backup_retention_days
  geo_redundant_backup_enabled  = var.environment == "prod"
  delegated_subnet_id           = var.subnet_id
  private_dns_zone_id           = local.dns_id
  public_network_access_enabled = false
  zone                          = "1"
  tags                          = local.tags

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  dynamic "high_availability" {
    for_each = var.ha ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = "2"
    }
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.this]
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "this" {
  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = local.rg_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = local.admin
  principal_name      = var.entra_admin_name
  principal_type      = var.entra_admin_type
}
