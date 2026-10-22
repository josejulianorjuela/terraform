locals {
  tags   = merge(var.tags, { team = var.team, environment = var.environment, requester = var.requester, "managed-by" = "plantillas-jjol" })
  labels = { for k, v in local.tags : lower(replace(k, "/[^a-zA-Z0-9_-]/", "_")) => substr(lower(replace(v, "/[^a-zA-Z0-9_-]/", "-")), 0, 63) }
  base   = "${var.name}-${var.environment}"
  # Rango de Identity-Aware Proxy para SSH sin IP pública.
  iap_range = "35.235.240.0/20"
}

resource "google_compute_network" "this" {
  name                    = "vpc-${local.base}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  for_each                 = { app = 0, datos = 1 }
  name                     = "snet-${each.key}-${local.base}"
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = cidrsubnet(var.cidr, 4, each.value)
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "internal" {
  name          = "fw-${local.base}-interno"
  network       = google_compute_network.this.id
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [var.cidr]

  allow {
    protocol = "all"
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "iap_ssh" {
  name          = "fw-${local.base}-iap-ssh"
  network       = google_compute_network.this.id
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [local.iap_range]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "deny_all" {
  name          = "fw-${local.base}-denegar"
  network       = google_compute_network.this.id
  direction     = "INGRESS"
  priority      = 65000
  source_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "all"
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router" "this" {
  count   = var.nat ? 1 : 0
  name    = "rtr-${local.base}"
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  count                              = var.nat ? 1 : 0
  name                               = "nat-${local.base}"
  router                             = google_compute_router.this[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  enable_dynamic_port_allocation     = true

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Acceso privado a servicios: Cloud SQL con IP privada usa este peering.
resource "google_compute_global_address" "private_services" {
  count         = var.private_services ? 1 : 0
  name          = "psa-${local.base}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "this" {
  count                   = var.private_services ? 1 : 0
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services[0].name]
}
