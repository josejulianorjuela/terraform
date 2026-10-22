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

variable "cidr" {
  description = "Espacio de direcciones de la VNet."
  type        = string
  default     = "10.10.0.0/16"
  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "Escriba un CIDR válido, por ejemplo 10.10.0.0/16."
  }
}

variable "nat" {
  description = "Crea un NAT Gateway para la salida a Internet de las subredes privadas."
  type        = bool
  default     = true
}

variable "zones" {
  description = "Zonas de disponibilidad del NAT (1 a 3)."
  type        = number
  default     = 1
}

variable "flow_logs_retention_days" {
  description = "Días de retención de los registros de red. En Azure no se usa: los flow logs de VNet dependen de Network Watcher, que se administra por suscripción fuera de la plantilla."
  type        = number
  default     = 30
}
