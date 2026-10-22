locals {
  tags      = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  base      = "${var.name}-${var.environment}"
  namespace = var.namespace != "" ? var.namespace : local.base
  # Valores de etiqueta válidos en Kubernetes: letras, números, '-', '_' y '.', hasta 63 caracteres.
  labels   = { for k, v in local.tags : lower(replace(k, "/[^a-zA-Z0-9_.-]/", "-")) => trim(substr(replace(v, "/[^a-zA-Z0-9_.-]/", "-"), 0, 63), "-_.") }
  selector = { "app.kubernetes.io/name" = var.name, "app.kubernetes.io/instance" = local.base }
  all      = merge(local.labels, local.selector, { "app.kubernetes.io/managed-by" = "plantillas-jjol" })
  ns       = var.create_namespace ? kubernetes_namespace_v1.this[0].metadata[0].name : local.namespace
}

resource "kubernetes_namespace_v1" "this" {
  count = var.create_namespace ? 1 : 0
  metadata {
    name = local.namespace
    labels = merge(local.labels, {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    })
  }
}

resource "kubernetes_service_account_v1" "this" {
  metadata {
    name      = local.base
    namespace = local.ns
    labels    = local.all
  }
  automount_service_account_token = false
}

resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = local.base
    namespace = local.ns
    labels    = local.all
  }

  spec {
    replicas = var.min_replicas

    selector {
      match_labels = local.selector
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "25%"
        max_unavailable = "0"
      }
    }

    template {
      metadata {
        labels = local.all
      }

      spec {
        service_account_name            = kubernetes_service_account_v1.this.metadata[0].name
        automount_service_account_token = false

        security_context {
          run_as_non_root = true
          run_as_user     = 10001
          run_as_group    = 10001
          fs_group        = 10001
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "topology.kubernetes.io/zone"
          when_unsatisfiable = "ScheduleAnyway"
          label_selector {
            match_labels = local.selector
          }
        }

        container {
          name              = "app"
          image             = var.image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = var.port
          }

          resources {
            requests = {
              cpu    = "${var.cpu * 1000}m"
              memory = "${var.memory_mb}Mi"
            }
            limits = {
              cpu    = "${var.cpu * 2000}m"
              memory = "${var.memory_mb}Mi"
            }
          }

          security_context {
            run_as_non_root            = true
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            privileged                 = false
            capabilities {
              drop = ["ALL"]
            }
          }

          readiness_probe {
            tcp_socket {
              port = var.port
            }
            period_seconds = 10
          }

          liveness_probe {
            tcp_socket {
              port = var.port
            }
            initial_delay_seconds = 10
            period_seconds        = 20
          }

          # Raíz de solo lectura: /tmp queda en un volumen efímero.
          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "tmp"
          empty_dir {
            size_limit = "256Mi"
          }
        }
      }
    }
  }

  # El HPA administra las réplicas.
  lifecycle {
    ignore_changes = [spec[0].replicas]
  }
}

resource "kubernetes_service_v1" "this" {
  metadata {
    name      = local.base
    namespace = local.ns
    labels    = local.all
  }
  spec {
    type     = "ClusterIP"
    selector = local.selector
    port {
      name        = "http"
      port        = 80
      target_port = var.port
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "this" {
  metadata {
    name      = local.base
    namespace = local.ns
    labels    = local.all
  }
  spec {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.this.metadata[0].name
    }
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}

resource "kubernetes_pod_disruption_budget_v1" "this" {
  metadata {
    name      = local.base
    namespace = local.ns
    labels    = local.all
  }
  spec {
    max_unavailable = "1"
    selector {
      match_labels = local.selector
    }
  }
}

# Entrada solo desde el mismo namespace y el controlador de ingress; salida sin el servicio de metadatos.
resource "kubernetes_network_policy_v1" "this" {
  metadata {
    name      = local.base
    namespace = local.ns
    labels    = local.all
  }
  spec {
    policy_types = ["Ingress", "Egress"]
    pod_selector {
      match_labels = local.selector
    }

    ingress {
      ports {
        port     = tostring(var.port)
        protocol = "TCP"
      }
      from {
        pod_selector {}
      }
      from {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = var.ingress_namespace }
        }
      }
    }

    egress {
      to {
        ip_block {
          cidr   = "0.0.0.0/0"
          except = ["169.254.169.254/32"]
        }
      }
    }

    egress {
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
      to {
        namespace_selector {}
      }
    }
  }
}

resource "kubernetes_ingress_v1" "this" {
  count = var.ingress_host != "" ? 1 : 0
  metadata {
    name      = local.base
    namespace = local.ns
    labels    = local.all
  }
  spec {
    ingress_class_name = var.ingress_class
    tls {
      hosts       = [var.ingress_host]
      secret_name = var.tls_secret != "" ? var.tls_secret : "${local.base}-tls"
    }
    rule {
      host = var.ingress_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.this.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
