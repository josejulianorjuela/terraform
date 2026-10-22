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

variable "region" {
  description = "Región de AWS."
  type        = string
  default     = "us-east-1"
}

# --- Variables de la plantilla -----------------------------------------------------------------------

variable "cidr" {
  description = "Bloque CIDR de la VPC."
  type        = string
  default     = "10.10.0.0/16"
  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "Escriba un CIDR válido, por ejemplo 10.10.0.0/16."
  }
}

variable "nat" {
  description = "Crea NAT Gateways (uno por zona) para la salida a Internet de las subredes privadas."
  type        = bool
  default     = true
}

variable "zones" {
  description = "Cantidad de zonas de disponibilidad (1 a 3)."
  type        = number
  default     = 1
  validation {
    condition     = var.zones >= 1 && var.zones <= 3
    error_message = "Use de 1 a 3 zonas."
  }
}

variable "flow_logs_retention_days" {
  description = "Días de retención de los flow logs en CloudWatch."
  type        = number
  default     = 30
}
