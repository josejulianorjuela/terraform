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

variable "kubeconfig_path" {
  description = "Ruta del kubeconfig del runner."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Contexto del kubeconfig; vacío para el actual."
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Namespace de la aplicación; vacío para usar el nombre."
  type        = string
  default     = ""
}

# --- Variables de la plantilla -----------------------------------------------------------------------

variable "create_namespace" {
  description = "Crea el namespace (con Pod Security 'restricted')."
  type        = bool
  default     = true
}

variable "image" {
  description = "Imagen del contenedor (debe correr como usuario no root)."
  type        = string
  default     = "nginxinc/nginx-unprivileged:stable-alpine"
}

variable "port" {
  description = "Puerto en el que escucha el contenedor."
  type        = number
  default     = 8080
}

variable "ingress_host" {
  description = "Nombre DNS público; vacío para no crear Ingress."
  type        = string
  default     = ""
}

variable "ingress_class" {
  description = "Clase de Ingress."
  type        = string
  default     = "nginx"
}

variable "ingress_namespace" {
  description = "Namespace del controlador de Ingress (se le permite la entrada en la NetworkPolicy)."
  type        = string
  default     = "ingress-nginx"
}

variable "tls_secret" {
  description = "Secreto TLS del Ingress; vacío para <nombre>-<ambiente>-tls (p. ej. emitido por cert-manager)."
  type        = string
  default     = ""
}

variable "cpu" {
  description = "vCPU solicitadas por réplica (el límite es el doble)."
  type        = number
  default     = 0.25
}

variable "memory_mb" {
  description = "Memoria por réplica en MB (solicitud = límite)."
  type        = number
  default     = 256
}

variable "min_replicas" {
  description = "Réplicas mínimas."
  type        = number
  default     = 2
}

variable "max_replicas" {
  description = "Réplicas máximas."
  type        = number
  default     = 4
}
