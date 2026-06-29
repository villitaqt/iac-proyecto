output "rds_endpoint" {
  description = "Endpoint (host:puerto) de la instancia RDS"
  value       = aws_db_instance.main.endpoint
}

output "rds_port" {
  description = "Puerto de RDS"
  value       = aws_db_instance.main.port
}

output "rds_database_name" {
  description = "Nombre de la base de datos inicial en RDS"
  value       = aws_db_instance.main.db_name
}

output "redis_primary_endpoint" {
  description = "Endpoint del nodo primario de Redis"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_port" {
  description = "Puerto de Redis"
  value       = aws_elasticache_replication_group.main.port
}
