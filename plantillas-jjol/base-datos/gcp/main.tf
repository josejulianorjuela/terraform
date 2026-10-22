locals {
  tags    = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  labels  = { for k, v in local.tags : lower(replace(k, "/[^a-zA-Z0-9_-]/", "_")) => substr(lower(replace(v, "/[^a-zA-Z0-9_-]/", "-")), 0, 63) }
  base    = "${var.name}-${var.environment}"
  is_prod = var.environment == "prod"
}

# IP privada solamente (requiere acceso privado a servicios en la VPC: red-base lo crea), SSL obligatorio,
# copias diarias con recuperación a un punto en el tiempo y autenticación IAM.
resource "google_sql_database_instance" "this" {
  name                = local.base
  region              = var.region
  database_version    = "POSTGRES_${var.postgres_version}"
  deletion_protection = local.is_prod

  settings {
    tier                        = "db-custom-${var.cpu}-${var.memory_gb * 1024}"
    edition                     = "ENTERPRISE"
    availability_type           = var.ha ? "REGIONAL" : "ZONAL"
    disk_type                   = "PD_SSD"
    disk_size                   = var.storage_gb
    disk_autoresize             = true
    deletion_protection_enabled = local.is_prod
    user_labels                 = local.labels

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network
      ssl_mode                                      = "ENCRYPTED_ONLY"
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
      transaction_log_retention_days = min(7, var.backup_retention_days)
      backup_retention_settings {
        retained_backups = var.backup_retention_days
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = 7
      hour         = 5
      update_track = "stable"
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"
    }

    insights_config {
      query_insights_enabled = true
    }
  }
}
