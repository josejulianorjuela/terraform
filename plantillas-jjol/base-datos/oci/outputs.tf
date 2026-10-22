output "host" {
  description = "IP privada del endpoint principal."
  value       = oci_psql_db_system.this.network_details[0].primary_db_endpoint_private_ip
}

output "port" {
  description = "Puerto de PostgreSQL."
  value       = "5432"
}

output "db_system_id" {
  description = "OCID del sistema de base de datos."
  value       = oci_psql_db_system.this.id
}
