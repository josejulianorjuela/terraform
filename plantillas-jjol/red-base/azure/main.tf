locals {
  tags     = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  base     = "${var.name}-${var.environment}"
  rg_name  = var.resource_group_name != "" ? var.resource_group_name : azurerm_resource_group.this[0].name
  nat_zone = var.zones > 1 ? null : ["1"]
  # Subredes: app (cargas), integracion (delegada a Container Apps / Functions Flex), datos (PostgreSQL), endpoints.
  subnets = {
    app         = { cidr = cidrsubnet(var.cidr, 4, 0), delegation = null, endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"] }
    integracion = { cidr = cidrsubnet(var.cidr, 4, 1), delegation = "Microsoft.App/environments", endpoints = ["Microsoft.Storage"] }
    datos       = { cidr = cidrsubnet(var.cidr, 4, 2), delegation = "Microsoft.DBforPostgreSQL/flexibleServers", endpoints = [] }
    endpoints   = { cidr = cidrsubnet(var.cidr, 4, 3), delegation = null, endpoints = [] }
  }
}

resource "azurerm_resource_group" "this" {
  count    = var.resource_group_name == "" ? 1 : 0
  name     = "rg-${local.base}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${local.base}"
  location            = var.location
  resource_group_name = local.rg_name
  address_space       = [var.cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  for_each                        = local.subnets
  name                            = "snet-${each.key}"
  resource_group_name             = local.rg_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [each.value.cidr]
  default_outbound_access_enabled = false

  dynamic "service_endpoint" {
    for_each = each.value.endpoints
    content {
      service = service_endpoint.value
    }
  }

  dynamic "delegation" {
    for_each = each.value.delegation == null ? [] : [each.value.delegation]
    content {
      name = "delegacion"
      service_delegation {
        name = delegation.value
      }
    }
  }
}

# Un NSG por VNet: niega explícitamente la entrada desde Internet y permite el tráfico interno.
resource "azurerm_network_security_group" "this" {
  name                = "nsg-${local.base}"
  location            = var.location
  resource_group_name = local.rg_name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "deny_internet" {
  name                        = "deny-internet-inbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = local.rg_name
  network_security_group_name = azurerm_network_security_group.this.name
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = azurerm_subnet.this
  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_public_ip" "nat" {
  count               = var.nat ? 1 : 0
  name                = "pip-nat-${local.base}"
  location            = var.location
  resource_group_name = local.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones > 1 ? ["1", "2", "3"] : ["1"]
  tags                = local.tags
}

resource "azurerm_nat_gateway" "this" {
  count                   = var.nat ? 1 : 0
  name                    = "ng-${local.base}"
  location                = var.location
  resource_group_name     = local.rg_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = local.nat_zone
  tags                    = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count                = var.nat ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  for_each       = var.nat ? { for k in ["app", "integracion"] : k => azurerm_subnet.this[k].id } : {}
  subnet_id      = each.value
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}
