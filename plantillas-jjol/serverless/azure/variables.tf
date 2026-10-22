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

variable "language" {
  description = "Lenguaje de la función: python o node."
  type        = string
  default     = "python"
  validation {
    condition     = contains(["python", "node"], var.language)
    error_message = "Use python o node."
  }
}

variable "memory_mb" {
  description = "Memoria por instancia en MB."
  type        = number
  default     = 512
}

variable "timeout_s" {
  description = "Tiempo máximo de ejecución en segundos."
  type        = number
  default     = 30
}

variable "max_instances" {
  description = "Instancias concurrentes máximas."
  type        = number
  default     = 10
}

variable "subnet_id" {
  description = "Subred delegada a Microsoft.App/environments con endpoint de servicio Microsoft.Storage (la subred 'integracion' de red-base)."
  type        = string
}
