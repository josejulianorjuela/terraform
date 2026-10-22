locals {
  tags        = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  base        = "${var.name}-${var.environment}"
  public_ecr  = startswith(var.image, "public.ecr.aws/")
  private_ecr = can(regex("^[0-9]{12}\\.dkr\\.ecr\\.", var.image))
}

# Repositorio privado: etiquetas inmutables, análisis al subir y limpieza de imágenes sin etiqueta.
resource "aws_ecr_repository" "this" {
  name                 = local.base
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Elimina imágenes sin etiqueta después de 14 días"
      selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 14 }
      action       = { type = "expire" }
    }]
  })
}

data "aws_iam_policy_document" "access_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["build.apprunner.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "instance_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["tasks.apprunner.amazonaws.com"]
    }
  }
}

# Rol con el que App Runner descarga la imagen de ECR privado.
resource "aws_iam_role" "access" {
  name               = "apprunner-ecr-${local.base}"
  assume_role_policy = data.aws_iam_policy_document.access_assume.json
}

resource "aws_iam_role_policy_attachment" "access" {
  role       = aws_iam_role.access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# Rol de la aplicación (sin permisos: se agregan según lo que necesite).
resource "aws_iam_role" "instance" {
  name               = "apprunner-app-${local.base}"
  assume_role_policy = data.aws_iam_policy_document.instance_assume.json
}

resource "aws_apprunner_auto_scaling_configuration_version" "this" {
  auto_scaling_configuration_name = substr(local.base, 0, 32)
  min_size                        = max(1, var.min_replicas)
  max_size                        = max(1, var.max_replicas)
  max_concurrency                 = 100
}

resource "aws_apprunner_service" "this" {
  service_name                   = local.base
  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.this.arn

  source_configuration {
    auto_deployments_enabled = false

    dynamic "authentication_configuration" {
      for_each = local.public_ecr ? [] : [1]
      content {
        access_role_arn = aws_iam_role.access.arn
      }
    }

    image_repository {
      image_identifier      = var.image
      image_repository_type = local.public_ecr ? "ECR_PUBLIC" : "ECR"
      image_configuration {
        port = tostring(var.port)
      }
    }
  }

  instance_configuration {
    cpu               = "${var.cpu} vCPU"
    memory            = "${var.memory_gb} GB"
    instance_role_arn = aws_iam_role.instance.arn
  }

  network_configuration {
    ingress_configuration {
      is_publicly_accessible = var.public
    }
  }

  health_check_configuration {
    protocol = "TCP"
  }

  lifecycle {
    precondition {
      condition     = local.public_ecr || local.private_ecr
      error_message = "App Runner solo descarga imágenes de ECR privado o de ECR Public (public.ecr.aws)."
    }
  }

  depends_on = [aws_iam_role_policy_attachment.access]
}
