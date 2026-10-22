# --- Variables comunes (todas las plantillas las aceptan) ---------------------------------

variable "name" {
  description = "Nombre de la carga: minúsculas, números y guiones."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,22}[a-z0-9]$", var.name))
    error_message = "Use de 3 a 24 caracteres: minúsculas, números y guiones; empiece con letra."
  }
}

variable "environment" {
  description = "Ambiente: dev, test o prod."
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "El ambiente debe ser dev, test o prod."
  }
}

variable "team" {
  description = "Equipo dueño (etiqueta team)."
  type        = string
}

variable "requester" {
  description = "Quién pidió el recurso (etiqueta requester)."
  type        = string
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
}

variable "subscription_id" {
  description = "Suscripción de Azure."
  type        = string
}

variable "location" {
  description = "Región de Azure."
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Grupo de recursos existente; vacío para crear uno."
  type        = string
  default     = ""
}

# --- Variables de la plantilla -----------------------------------------------------------------------

variable "postgres_version" {
  description = "Versión mayor de PostgreSQL."
  type        = string
  default     = "16"
  validation {
    condition     = contains(["15", "16", "17"], var.postgres_version)
    error_message = "Use PostgreSQL 15, 16 o 17."
  }
}

variable "admin_username" {
  description = "Usuario administrador inicial."
  type        = string
  default     = "app_admin"
}

variable "allowed_cidr" {
  description = "Red privada que puede conectarse al puerto 5432."
  type        = string
  default     = "10.0.0.0/8"
}

variable "cpu" {
  description = "vCPU de la instancia (2, 4 u 8)."
  type        = number
  default     = 2
}

variable "memory_gb" {
  description = "Memoria en GB."
  type        = number
  default     = 8
}

variable "storage_gb" {
  description = "Almacenamiento inicial en GB."
  type        = number
  default     = 32
}

variable "ha" {
  description = "Alta disponibilidad entre zonas."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Días de retención de las copias automáticas."
  type        = number
  default     = 7
}

variable "subnet_id" {
  description = "Subred delegada a Microsoft.DBforPostgreSQL/flexibleServers (la subred 'datos' de red-base)."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Zona DNS privada existente (*.postgres.database.azure.com); vacío para crear una y enlazarla a la VNet."
  type        = string
  default     = ""
}

variable "entra_admin_object_id" {
  description = "Object id del administrador de Entra ID; vacío para usar la identidad del runner."
  type        = string
  default     = ""
}

variable "entra_admin_name" {
  description = "Nombre del administrador de Entra ID."
  type        = string
  default     = "terraform-runner"
}

variable "entra_admin_type" {
  description = "Tipo del administrador: User, Group o ServicePrincipal."
  type        = string
  default     = "ServicePrincipal"
}
