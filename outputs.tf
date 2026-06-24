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
