locals {
  tags    = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  base    = "${var.name}-${var.environment}"
  rg_name = var.resource_group_name != "" ? var.resource_group_name : azurerm_resource_group.this[0].name
  suffix  = substr(sha1("${var.subscription_id}/${local.base}"), 0, 6)
  st_name = substr(replace("st${var.name}${var.environment}${local.suffix}", "-", ""), 0, 24)
  runtime = { python = "3.12", node = "22" }
  # Flex Consumption admite 512, 2048 o 4096 MB y al menos 40 instancias máximas.
  memory = var.memory_mb <= 512 ? 512 : (var.memory_mb <= 2048 ? 2048 : 4096)
}

resource "azurerm_resource_group" "this" {
  count    = var.resource_group_name == "" ? 1 : 0
  name     = "rg-${local.base}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                         = "log-${local.base}"
  location                     = var.location
  resource_group_name          = local.rg_name
  sku                          = "PerGB2018"
  retention_in_days            = 30
  local_authentication_enabled = false
  tags                         = local.tags
}

resource "azurerm_application_insights" "this" {
  name                = "appi-${local.base}"
  location            = var.location
  resource_group_name = local.rg_name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "other"
  tags                = local.tags
}

# Almacenamiento sin llaves compartidas ni acceso anónimo, solo HTTPS/TLS 1.2 y firewall que permite
# únicamente la subred de integración de la función.
resource "azurerm_storage_account" "this" {
  name                             = local.st_name
  location                         = var.location
  resource_group_name              = local.rg_name
  account_tier                     = "Standard"
  account_replication_type         = var.environment == "prod" ? "ZRS" : "LRS"
  account_kind                     = "StorageV2"
  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true
  allow_nested_items_to_be_public  = false
  shared_access_key_enabled        = false
  default_to_oauth_authentication  = true
  cross_tenant_replication_enabled = false
  tags                             = local.tags

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [var.subnet_id]
  }
}

resource "azurerm_storage_container" "deploy" {
  name                  = "despliegues"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_storage_queue" "this" {
  name               = "trabajos"
  storage_account_id = azurerm_storage_account.this.id
}

resource "azurerm_service_plan" "this" {
  name                = "asp-${local.base}"
  location            = var.location
  resource_group_name = local.rg_name
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = local.tags
}

resource "azurerm_function_app_flex_consumption" "this" {
  name                          = "func-${local.base}-${local.suffix}"
  location                      = var.location
  resource_group_name           = local.rg_name
  service_plan_id               = azurerm_service_plan.this.id
  storage_container_type        = "blobContainer"
  storage_container_endpoint    = "${azurerm_storage_account.this.primary_blob_endpoint}${azurerm_storage_container.deploy.name}"
  storage_authentication_type   = "SystemAssignedIdentity"
  runtime_name                  = var.language
  runtime_version               = local.runtime[var.language]
  instance_memory_in_mb         = local.memory
  maximum_instance_count        = max(40, var.max_instances)
  https_only                    = true
  public_network_access_enabled = false
  virtual_network_subnet_id     = var.subnet_id
  tags                          = local.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version                    = "1.2"
    http2_enabled                          = true
    application_insights_connection_string = azurerm_application_insights.this.connection_string
  }

  app_settings = {
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.this.name
    "QUEUE_NAME"                       = azurerm_storage_queue.this.name
    "FUNCTION_TIMEOUT_SECONDS"         = tostring(var.timeout_s)
  }
}

resource "azurerm_role_assignment" "blob" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "queue" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}
