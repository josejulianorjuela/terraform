output "function_name" {
  description = "Nombre de la función Lambda."
  value       = aws_lambda_function.this.function_name
}

output "queue" {
  description = "URL de la cola SQS que dispara la función."
  value       = aws_sqs_queue.this.url
}

output "role_arn" {
  description = "Rol IAM de la función."
  value       = aws_iam_role.this.arn
}
