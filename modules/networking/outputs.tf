output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block de la VPC"
  value       = aws_vpc.main.cidr_block
}

output "azs" {
  description = "AZs usadas por la red"
  value       = local.azs
}

output "public_subnet_ids" {
  description = "IDs de las subnets públicas"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs de las subnets privadas de aplicación"
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "IDs de las subnets privadas de datos"
  value       = aws_subnet.private_data[*].id
}

output "private_app_route_table_ids" {
  description = "IDs de las route tables privadas de aplicación, una por AZ"
  value       = aws_route_table.private_app[*].id
}
