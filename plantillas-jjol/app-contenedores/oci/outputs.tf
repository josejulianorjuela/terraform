output "url" {
  description = "Dirección de la aplicación (IP privada de la VNIC; publíquela con un balanceador con TLS)."
  value       = "http://${oci_container_instances_container_instance.this.vnics[0].private_ip}:${var.port}"
}

output "registry" {
  description = "Repositorio de OCIR (si se creó)."
  value       = var.create_registry ? oci_artifacts_container_repository.this[0].display_name : ""
}

output "container_instance_id" {
  description = "OCID de la instancia de contenedores."
  value       = oci_container_instances_container_instance.this.id
}
