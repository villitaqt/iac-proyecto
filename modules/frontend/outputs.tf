output "domain_name" {
  description = "Dominio público de CloudFront para acceder al frontend"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "distribution_id" {
  description = "ID de la distribución, necesario para invalidar caché"
  value       = aws_cloudfront_distribution.frontend.id
}

output "bucket_name" {
  description = "Nombre del bucket donde se sube el build de Vite"
  value       = aws_s3_bucket.frontend.bucket
}
