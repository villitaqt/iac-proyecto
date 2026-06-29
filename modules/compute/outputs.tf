output "ecr_repository_url" {
  description = "URL del repositorio ECR para hacer push de la imagen del backend"
  value       = aws_ecr_repository.backend.repository_url
}

output "task_execution_role_arn" {
  description = "ARN del rol de ejecucion (pull de ECR, logs, lectura de secretos)"
  value       = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  description = "ARN del rol de la tarea (usado por el codigo de la app)"
  value       = aws_iam_role.task_role.arn
}
