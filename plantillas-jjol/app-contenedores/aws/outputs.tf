output "url" {
  description = "URL HTTPS de la aplicación."
  value       = "https://${aws_apprunner_service.this.service_url}"
}

output "registry" {
  description = "Repositorio de ECR para las imágenes de la aplicación."
  value       = aws_ecr_repository.this.repository_url
}

output "instance_role_arn" {
  description = "Rol IAM de la aplicación."
  value       = aws_iam_role.instance.arn
}
