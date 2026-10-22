locals {
  tags = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  base = "${var.name}-${var.environment}"
  # OCI Functions admite hasta 3072 MB y 300 s en modo síncrono.
  memory  = min(3072, max(128, var.memory_mb))
  timeout = min(300, var.timeout_s)
}

resource "oci_functions_application" "this" {
  compartment_id = var.compartment_id
  display_name   = local.base
  subnet_ids     = [var.subnet_id]
  shape          = "GENERIC_X86"
  freeform_tags  = local.tags

  trace_config {
    is_enabled = true
  }
}

resource "oci_functions_function" "this" {
  application_id     = oci_functions_application.this.id
  display_name       = local.base
  memory_in_mbs      = local.memory
  timeout_in_seconds = local.timeout
  config             = { STREAM = local.base, LANGUAGE = var.language }
  freeform_tags      = local.tags

  source_details {
    source_type = "IMAGE"
    image       = var.image
  }

  trace_config {
    is_enabled = true
  }
}

resource "oci_streaming_stream_pool" "this" {
  compartment_id = var.compartment_id
  name           = "pool-${local.base}"
  freeform_tags  = local.tags
}

resource "oci_streaming_stream" "this" {
  name               = local.base
  partitions         = max(1, ceil(var.max_instances / 10))
  retention_in_hours = 24
  stream_pool_id     = oci_streaming_stream_pool.this.id
  freeform_tags      = local.tags
}

# Connector Hub lee el stream y llama a la función.
resource "oci_sch_service_connector" "this" {
  compartment_id = var.compartment_id
  display_name   = "sch-${local.base}"
  description    = "Stream ${local.base} → función ${local.base}"
  freeform_tags  = local.tags

  source {
    kind      = "streaming"
    stream_id = oci_streaming_stream.this.id
    cursor {
      kind = "LATEST"
    }
  }

  target {
    kind              = "functions"
    function_id       = oci_functions_function.this.id
    batch_size_in_num = 10
    batch_time_in_sec = 5
  }

  depends_on = [oci_identity_policy.connector]
}

resource "oci_identity_policy" "connector" {
  compartment_id = var.compartment_id
  name           = "sch-${local.base}"
  description    = "Connector Hub de ${local.base}: leer el stream e invocar la función"
  freeform_tags  = local.tags
  statements = [
    "allow any-user to {STREAM_READ, STREAM_CONSUME} in compartment id ${var.compartment_id} where all {request.principal.type='serviceconnector', target.stream.id='${oci_streaming_stream.this.id}'}",
    "allow any-user to use fn-function in compartment id ${var.compartment_id} where all {request.principal.type='serviceconnector'}",
    "allow any-user to use fn-invocation in compartment id ${var.compartment_id} where all {request.principal.type='serviceconnector'}",
  ]
}
