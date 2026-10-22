output "function_name" {
  description = "Nombre de la función."
  value       = oci_functions_function.this.display_name
}

output "queue" {
  description = "OCID del stream que dispara la función."
  value       = oci_streaming_stream.this.id
}

output "url" {
  description = "Endpoint de invocación de la función (requiere firma de OCI)."
  value       = oci_functions_function.this.invoke_endpoint
}
