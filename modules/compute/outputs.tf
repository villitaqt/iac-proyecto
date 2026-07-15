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

output "alb_dns_name" {
  description = "DNS publico del ALB"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN del ALB"
  value       = aws_lb.main.arn
}

output "alb_zone_id" {
  description = "Zone ID del ALB, necesario para un alias de Route53"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "ARN del target group del backend (aun sin targets registrados)"
  value       = aws_lb_target_group.backend.arn
}

output "ecs_cluster_name" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Nombre del servicio ECS del backend"
  value       = aws_ecs_service.backend.name
}

output "log_group_name" {
  description = "Nombre del log group de CloudWatch del backend"
  value       = aws_cloudwatch_log_group.backend.name
}
