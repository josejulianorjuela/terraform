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

variable "image" {
  description = "Imagen del contenedor (registro/repositorio:etiqueta)."
  type        = string
  default     = "public.ecr.aws/nginx/nginx-unprivileged:stable-alpine"
}

variable "port" {
  description = "Puerto en el que escucha el contenedor."
  type        = number
  default     = 8080
}

variable "public" {
  description = "Expone la aplicación a Internet (HTTPS). Falso: solo tráfico interno."
  type        = bool
  default     = false
}

variable "cpu" {
  description = "vCPU por réplica."
  type        = number
  default     = 0.5
}

variable "memory_gb" {
  description = "Memoria por réplica en GB."
  type        = number
  default     = 1
}

variable "min_replicas" {
  description = "Réplicas mínimas (0 permite escalar a cero donde la nube lo admite)."
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "Réplicas máximas."
  type        = number
  default     = 3
}

variable "allow_unauthenticated" {
  description = "Permite invocar el servicio sin autenticación (allUsers). es un riesgo de seguridad alto."
  type        = bool
  default     = false
}
