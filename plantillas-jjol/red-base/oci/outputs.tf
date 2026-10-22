output "network_id" {
  description = "Id de la red (VNet, VPC o VCN)."
  value       = oci_core_vcn.this.id
}

output "subnets" {
  description = "Subredes por nombre, en JSON."
  value       = jsonencode({ privada = oci_core_subnet.private.id, publica = oci_core_subnet.public.id })
}

output "vcn_id" {
  description = "OCID de la VCN."
  value       = oci_core_vcn.this.id
}

output "private_subnet_id" {
  description = "OCID de la subred privada."
  value       = oci_core_subnet.private.id
}

output "public_subnet_id" {
  description = "OCID de la subred pública."
  value       = oci_core_subnet.public.id
}
