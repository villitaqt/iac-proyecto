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
