output "host" {
  description = "Endpoint privado de la base de datos."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Puerto de PostgreSQL."
  value       = tostring(aws_db_instance.this.port)
}

output "admin_secret_arn" {
  description = "Secreto de Secrets Manager con la contraseña maestra."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
