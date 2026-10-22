locals {
  tags = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  base = "${var.name}-${var.environment}"
  # 1 OCPU = 2 vCPU; Container Instances pide al menos 1 OCPU.
  ocpus = max(1, ceil(var.cpu / 2))
}

data "oci_identity_availability_domains" "this" {
  compartment_id = var.compartment_id
}

# Repositorio privado e inmutable de OCIR (opcional).
resource "oci_artifacts_container_repository" "this" {
  count          = var.create_registry ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = local.base
  is_public      = false
  is_immutable   = true
  freeform_tags  = local.tags
}

resource "oci_container_instances_container_instance" "this" {
  compartment_id           = var.compartment_id
  availability_domain      = data.oci_identity_availability_domains.this.availability_domains[0].name
  display_name             = local.base
  shape                    = "CI.Standard.E4.Flex"
  container_restart_policy = "ALWAYS"
  freeform_tags            = local.tags

  shape_config {
    ocpus         = local.ocpus
    memory_in_gbs = max(var.memory_gb, local.ocpus)
  }

  vnics {
    subnet_id             = var.subnet_id
    is_public_ip_assigned = var.public
    display_name          = "vnic-${local.base}"
    freeform_tags         = local.tags
  }

  # Sistema de archivos raíz de solo lectura: /tmp queda en un volumen efímero.
  volumes {
    name        = "tmp"
    volume_type = "EMPTYDIR"
  }

  containers {
    display_name  = "app"
    image_url     = var.image
    freeform_tags = local.tags

    resource_config {
      vcpus_limit         = var.cpu
      memory_limit_in_gbs = var.memory_gb
    }

    security_context {
      security_context_type          = "LINUX"
      is_non_root_user_check_enabled = true
      is_root_file_system_readonly   = true
      run_as_user                    = 101
      run_as_group                   = 101
      capabilities {
        drop_capabilities = ["ALL"]
      }
    }

    volume_mounts {
      volume_name = "tmp"
      mount_path  = "/tmp"
    }

    health_checks {
      health_check_type = "TCP"
      port              = var.port
    }
  }
}
