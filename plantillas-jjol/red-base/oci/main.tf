locals {
  tags      = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  base      = "${var.name}-${var.environment}"
  dns_label = substr(replace("${var.name}${var.environment}", "-", ""), 0, 15)
  # OCI acepta retenciones de 30 a 180 días en múltiplos de 30.
  retention = min(180, max(30, floor(var.flow_logs_retention_days / 30) * 30))
}

data "oci_core_services" "all" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  display_name   = "vcn-${local.base}"
  cidr_blocks    = [var.cidr]
  dns_label      = local.dns_label
  freeform_tags  = local.tags
}

# La security list por defecto de OCI abre SSH desde Internet: se administra y queda solo con tráfico interno.
resource "oci_core_default_security_list" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_security_list_id
  display_name               = "sl-default-${local.base}"
  freeform_tags              = local.tags

  ingress_security_rules {
    protocol = "all"
    source   = var.cidr
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "igw-${local.base}"
  enabled        = true
  freeform_tags  = local.tags
}

resource "oci_core_nat_gateway" "this" {
  count          = var.nat ? 1 : 0
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "nat-${local.base}"
  freeform_tags  = local.tags
}

resource "oci_core_service_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "sgw-${local.base}"
  freeform_tags  = local.tags

  services {
    service_id = data.oci_core_services.all.services[0].id
  }
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "rt-publica-${local.base}"
  freeform_tags  = local.tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "rt-privada-${local.base}"
  freeform_tags  = local.tags

  dynamic "route_rules" {
    for_each = var.nat ? [1] : []
    content {
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
      network_entity_id = oci_core_nat_gateway.this[0].id
    }
  }

  route_rules {
    destination       = data.oci_core_services.all.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.this.id
  }
}

resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "sl-privada-${local.base}"
  freeform_tags  = local.tags

  ingress_security_rules {
    protocol = "all"
    source   = var.cidr
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# Subred pública: solo HTTPS desde Internet (balanceadores).
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "sl-publica-${local.base}"
  freeform_tags  = local.tags

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = var.cidr
  }
}

resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  display_name               = "snet-privada-${local.base}"
  cidr_block                 = cidrsubnet(var.cidr, 4, 8)
  dns_label                  = "privada"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  freeform_tags              = local.tags
}

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  display_name               = "snet-publica-${local.base}"
  cidr_block                 = cidrsubnet(var.cidr, 4, 0)
  dns_label                  = "publica"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  freeform_tags              = local.tags
}

resource "oci_logging_log_group" "this" {
  compartment_id = var.compartment_id
  display_name   = "lg-${local.base}"
  freeform_tags  = local.tags
}

resource "oci_logging_log" "flow" {
  for_each           = { privada = oci_core_subnet.private.id, publica = oci_core_subnet.public.id }
  display_name       = "flow-${each.key}-${local.base}"
  log_group_id       = oci_logging_log_group.this.id
  log_type           = "SERVICE"
  is_enabled         = true
  retention_duration = local.retention
  freeform_tags      = local.tags

  configuration {
    compartment_id = var.compartment_id
    source {
      category    = "all"
      resource    = each.value
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
  }
}
