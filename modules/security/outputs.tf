output "kms_key_arn" {
  description = "ARN de la CMK usada por RDS, Secrets Manager, S3 y logs"
  value       = aws_kms_key.main.arn
}

output "sg_alb_id" {
  description = "ID del security group del ALB"
  value       = aws_security_group.alb.id
}

output "sg_backend_id" {
  description = "ID del security group del backend"
  value       = aws_security_group.backend.id
}

output "sg_rds_id" {
  description = "ID del security group de RDS"
  value       = aws_security_group.rds.id
}

output "sg_redis_id" {
  description = "ID del security group de Redis"
  value       = aws_security_group.redis.id
}

output "secret_db_arn" {
  description = "ARN del secreto con credenciales de la base de datos"
  value       = aws_secretsmanager_secret.db.arn
}

output "secret_jwt_arn" {
  description = "ARN del secreto con el secreto HS256 para JWT"
  value       = aws_secretsmanager_secret.jwt.arn
}

output "secret_mercadopago_arn" {
  description = "ARN del secreto con el access_token de MercadoPago"
  value       = aws_secretsmanager_secret.mercadopago.arn
}
