output "frontend_url" {
  description = "URL pública del frontend servido por CloudFront"
  value       = "https://${module.frontend.domain_name}"
}

output "frontend_bucket" {
  description = "Bucket S3 donde se sube el build de Vite (dist/)"
  value       = module.frontend.bucket_name
}

output "frontend_distribution_id" {
  description = "ID de distribución de CloudFront, usado para invalidar caché"
  value       = module.frontend.distribution_id
}

output "vpc_id" {
  description = "ID de la VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs de las subnets públicas"
  value       = module.networking.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs de las subnets privadas de aplicación"
  value       = module.networking.private_app_subnet_ids
}

output "private_data_subnet_ids" {
  description = "IDs de las subnets privadas de datos"
  value       = module.networking.private_data_subnet_ids
}

output "kms_key_arn" {
  description = "ARN de la CMK compartida (RDS, Secrets Manager, S3, logs)"
  value       = module.security.kms_key_arn
}

output "sg_alb_id" {
  description = "ID del security group del ALB"
  value       = module.security.sg_alb_id
}

output "sg_backend_id" {
  description = "ID del security group del backend"
  value       = module.security.sg_backend_id
}

output "sg_rds_id" {
  description = "ID del security group de RDS"
  value       = module.security.sg_rds_id
}

output "sg_redis_id" {
  description = "ID del security group de Redis"
  value       = module.security.sg_redis_id
}

output "secret_db_arn" {
  description = "ARN del secreto con credenciales de la base de datos"
  value       = module.security.secret_db_arn
}

output "secret_jwt_arn" {
  description = "ARN del secreto con el secreto HS256 para JWT"
  value       = module.security.secret_jwt_arn
}

output "secret_mercadopago_arn" {
  description = "ARN del secreto con el access_token de MercadoPago"
  value       = module.security.secret_mercadopago_arn
}
