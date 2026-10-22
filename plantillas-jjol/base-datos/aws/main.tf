locals {
  tags       = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  base       = "${var.name}-${var.environment}"
  subnet_ids = [for s in split(",", var.subnet_ids) : trimspace(s) if trimspace(s) != ""]
  is_prod    = var.environment == "prod"
  classes    = { "2" = "db.t4g.medium", "4" = "db.m7g.xlarge", "8" = "db.m7g.2xlarge", "16" = "db.m7g.4xlarge" }
}

data "aws_subnet" "first" {
  id = local.subnet_ids[0]
}

resource "aws_db_subnet_group" "this" {
  name       = local.base
  subnet_ids = local.subnet_ids
}

# Solo la red privada indicada llega al 5432.
resource "aws_security_group" "this" {
  name        = "sg-db-${local.base}"
  description = "PostgreSQL desde la red privada"
  vpc_id      = data.aws_subnet.first.vpc_id

  ingress {
    description = "PostgreSQL"
    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    description = "Salida dentro de la red privada"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [var.allowed_cidr]
  }
}

resource "aws_db_parameter_group" "this" {
  name   = "${local.base}-pg${var.postgres_version}"
  family = "postgres${var.postgres_version}"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }
}

# Cifrada, privada, con copias automáticas; la contraseña maestra la guarda Secrets Manager.
resource "aws_db_instance" "this" {
  identifier                          = local.base
  engine                              = "postgres"
  engine_version                      = var.postgres_version
  instance_class                      = lookup(local.classes, tostring(var.cpu), "db.m7g.large")
  allocated_storage                   = var.storage_gb
  max_allocated_storage               = var.storage_gb * 4
  storage_type                        = "gp3"
  storage_encrypted                   = true
  username                            = var.admin_username
  manage_master_user_password         = true
  iam_database_authentication_enabled = true
  db_subnet_group_name                = aws_db_subnet_group.this.name
  vpc_security_group_ids              = [aws_security_group.this.id]
  parameter_group_name                = aws_db_parameter_group.this.name
  publicly_accessible                 = false
  multi_az                            = var.ha
  backup_retention_period             = var.backup_retention_days
  backup_window                       = "03:00-04:00"
  maintenance_window                  = "sun:05:00-sun:06:00"
  auto_minor_version_upgrade          = true
  copy_tags_to_snapshot               = true
  deletion_protection                 = local.is_prod
  skip_final_snapshot                 = !local.is_prod
  final_snapshot_identifier           = local.is_prod ? "${local.base}-final" : null
  performance_insights_enabled        = true
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]
}
