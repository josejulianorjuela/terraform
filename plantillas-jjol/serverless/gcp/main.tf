locals {
  tags    = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  labels  = { for k, v in local.tags : lower(replace(k, "/[^a-zA-Z0-9_-]/", "_")) => substr(lower(replace(v, "/[^a-zA-Z0-9_-]/", "-")), 0, 63) }
  base    = "${var.name}-${var.environment}"
  runtime = { python = "python312", node = "nodejs22" }
  code = {
    python = { file = "main.py", body = "import base64\nimport functions_framework\n\n\n@functions_framework.cloud_event\ndef handler(event):\n    print(base64.b64decode(event.data[\"message\"][\"data\"]).decode())\n" }
    node   = { file = "index.js", body = "const ff = require('@google-cloud/functions-framework');\nff.cloudEvent('handler', (e) => console.log(Buffer.from(e.data.message.data, 'base64').toString()));\n" }
  }
  memory = var.memory_mb >= 1024 ? "${floor(var.memory_mb / 1024)}Gi" : "${var.memory_mb}Mi"
}

data "archive_file" "code" {
  type        = "zip"
  output_path = "${path.module}/.build/${local.base}.zip"
  source {
    filename = local.code[var.language].file
    content  = local.code[var.language].body
  }
  dynamic "source" {
    for_each = var.language == "python" ? [1] : []
    content {
      filename = "requirements.txt"
      content  = "functions-framework==3.*\n"
    }
  }
  dynamic "source" {
    for_each = var.language == "node" ? [1] : []
    content {
      filename = "package.json"
      content  = jsonencode({ name = local.base, dependencies = { "@google-cloud/functions-framework" = "^3.0.0" } })
    }
  }
}

# Bucket del código: acceso uniforme y prevención de acceso público aplicada.
resource "google_storage_bucket" "source" {
  name                        = substr("${var.project_id}-${local.base}-src", 0, 63)
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 5
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_object" "code" {
  name   = "codigo-${data.archive_file.code.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.code.output_path
}

resource "google_pubsub_topic" "this" {
  name                       = local.base
  message_retention_duration = "86400s"

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

# Cuenta de servicio propia para construir, ejecutar e invocar la función.
resource "google_service_account" "this" {
  account_id   = substr("fn-${local.base}", 0, 30)
  display_name = "Función ${local.base}"
  description  = "Identidad de la función ${local.base} (plantillas-jjol)."
}

resource "google_project_iam_member" "this" {
  for_each = toset(["roles/logging.logWriter", "roles/artifactregistry.writer", "roles/eventarc.eventReceiver"])
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.this.email}"
}

resource "google_storage_bucket_iam_member" "source" {
  bucket = google_storage_bucket.source.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.this.email}"
}

resource "google_cloudfunctions2_function" "this" {
  name     = local.base
  location = var.region

  build_config {
    runtime         = local.runtime[var.language]
    entry_point     = "handler"
    service_account = google_service_account.this.id
    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.code.name
      }
    }
  }

  service_config {
    available_memory               = local.memory
    timeout_seconds                = var.timeout_s
    max_instance_count             = var.max_instances
    min_instance_count             = 0
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.this.email
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.this.id
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.this.email
  }

  depends_on = [google_project_iam_member.this, google_storage_bucket_iam_member.source]
}

# Eventarc invoca el servicio de la función con la misma cuenta de servicio (sin allUsers).
resource "google_cloud_run_service_iam_member" "invoker" {
  location = var.region
  service  = google_cloudfunctions2_function.this.service_config[0].service
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.this.email}"
}
