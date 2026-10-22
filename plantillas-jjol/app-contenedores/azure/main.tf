locals {
  tags    = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  base    = "${var.name}-${var.environment}"
  rg_name = var.resource_group_name != "" ? var.resource_group_name : azurerm_resource_group.this[0].name
  # Nombres globales sin guiones: sufijo estable derivado de la suscripción.
  suffix   = substr(sha1("${var.subscription_id}/${local.base}"), 0, 6)
  acr_name = substr(replace("acr${var.name}${var.environment}${local.suffix}", "-", ""), 0, 50)
  from_acr = startswith(var.image, "${local.acr_name}.azurecr.io/")
}

resource "azurerm_resource_group" "this" {
  count    = var.resource_group_name == "" ? 1 : 0
  name     = "rg-${local.base}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${local.base}"
  location            = var.location
  resource_group_name = local.rg_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# Registro privado: sin usuario administrador ni extracción anónima; las apps entran con identidad administrada.
resource "azurerm_container_registry" "this" {
  name                    = local.acr_name
  location                = var.location
  resource_group_name     = local.rg_name
  sku                     = "Standard"
  admin_enabled           = false
  anonymous_pull_enabled  = false
  zone_redundancy_enabled = false
  tags                    = local.tags
}

resource "azurerm_user_assigned_identity" "this" {
  name                = "id-${local.base}"
  location            = var.location
  resource_group_name = local.rg_name
  tags                = local.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_container_app_environment" "this" {
  name                       = "cae-${local.base}"
  location                   = var.location
  resource_group_name        = local.rg_name
  logs_destination           = "log-analytics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = local.tags
}

resource "azurerm_container_app" "this" {
  name                         = "ca-${local.base}"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = local.rg_name
  revision_mode                = "Single"
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }

  dynamic "registry" {
    for_each = local.from_acr ? [1] : []
    content {
      server   = azurerm_container_registry.this.login_server
      identity = azurerm_user_assigned_identity.this.id
    }
  }

  ingress {
    external_enabled           = var.public
    target_port                = var.port
    transport                  = "auto"
    allow_insecure_connections = false
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "app"
      image  = var.image
      cpu    = var.cpu
      memory = "${var.memory_gb}Gi"

      liveness_probe {
        transport = "TCP"
        port      = var.port
      }

      readiness_probe {
        transport = "TCP"
        port      = var.port
      }
    }
  }

  depends_on = [azurerm_role_assignment.acr_pull]
}
