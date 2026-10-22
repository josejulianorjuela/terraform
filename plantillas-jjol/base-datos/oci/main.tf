locals {
  tags  = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  base  = "${var.name}-${var.environment}"
  ocpus = max(1, floor(var.cpu / 2))
}

data "oci_core_subnet" "this" {
  subnet_id = var.subnet_id
}

# NSG: solo la red privada indicada llega al 5432.
resource "oci_core_network_security_group" "this" {
  compartment_id = var.compartment_id
  vcn_id         = data.oci_core_subnet.this.vcn_id
  display_name   = "nsg-db-${local.base}"
  freeform_tags  = local.tags
}

resource "oci_core_network_security_group_security_rule" "postgres" {
  network_security_group_id = oci_core_network_security_group.this.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.allowed_cidr
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 5432
      max = 5432
    }
  }
}

# Base privada en la subred, almacenamiento regional durable, contraseña en OCI Vault y copias diarias.
resource "oci_psql_db_system" "this" {
  compartment_id              = var.compartment_id
  display_name                = local.base
  db_version                  = var.postgres_version
  shape                       = "PostgreSQL.VM.Standard.E5.Flex"
  instance_ocpu_count         = local.ocpus
  instance_memory_size_in_gbs = var.memory_gb
  instance_count              = var.ha ? 2 : 1
  freeform_tags               = local.tags

  network_details {
    subnet_id = var.subnet_id
    nsg_ids   = [oci_core_network_security_group.this.id]
  }

  storage_details {
    system_type           = "OCI_OPTIMIZED_STORAGE"
    is_regionally_durable = true
  }

  credentials {
    username = var.admin_username
    password_details {
      password_type = "VAULT_SECRET"
      secret_id     = var.admin_password_secret_id
    }
  }

  management_policy {
    maintenance_window_start = "SUN 05:00"
    backup_policy {
      kind           = "DAILY"
      backup_start   = "03:00"
      retention_days = var.backup_retention_days
    }
  }
}
