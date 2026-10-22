output "network_id" {
  description = "Id de la red (VNet, VPC o VCN). En GCP es la entrada 'network' de base-datos."
  value       = google_compute_network.this.id
}

output "subnets" {
  description = "Subredes por nombre, en JSON."
  value       = jsonencode({ for k, s in google_compute_subnetwork.this : k => s.id })
}
