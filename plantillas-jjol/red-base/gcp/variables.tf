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

variable "project_id" {
  description = "Proyecto de Google Cloud."
  type        = string
}

variable "region" {
  description = "Región de Google Cloud."
  type        = string
  default     = "us-central1"
}

# --- Variables de la plantilla -----------------------------------------------------------------------

variable "cidr" {
  description = "Rango base de las subredes de la VPC."
  type        = string
  default     = "10.10.0.0/16"
  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "Escriba un CIDR válido, por ejemplo 10.10.0.0/16."
  }
}

variable "nat" {
  description = "Crea Cloud Router y Cloud NAT para la salida a Internet."
  type        = bool
  default     = true
}

variable "zones" {
  description = "No aplica en GCP (las subredes son regionales); se acepta por compatibilidad."
  type        = number
  default     = 1
}

variable "flow_logs_retention_days" {
  description = "No aplica en GCP (la retención la define el bucket de Cloud Logging); se acepta por compatibilidad."
  type        = number
  default     = 30
}

variable "private_services" {
  description = "Reserva un rango y conecta el acceso privado a servicios (Cloud SQL con IP privada)."
  type        = bool
  default     = true
}
