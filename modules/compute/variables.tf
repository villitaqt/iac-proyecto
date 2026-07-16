variable "project" {
  description = "Nombre del proyecto, usado en nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue (prod, staging, dev, etc.)"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN de la CMK compartida, usada para cifrar las imagenes en ECR"
  type        = string
}

variable "secret_db_arn" {
  description = "ARN del secreto vivevinyls/db"
  type        = string
}

variable "secret_jwt_arn" {
  description = "ARN del secreto vivevinyls/jwt"
  type        = string
}

variable "secret_redis_arn" {
  description = "ARN del secreto vivevinyls/redis"
  type        = string
}

variable "secret_mercadopago_arn" {
  description = "ARN del secreto vivevinyls/mercadopago"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC (viene del modulo networking)"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs de las subnets publicas, una por AZ (viene del modulo networking)"
  type        = list(string)
}

variable "sg_alb_id" {
  description = "ID del security group del ALB (viene del modulo security)"
  type        = string
}

variable "private_app_subnet_ids" {
  description = "IDs de las subnets privadas de app, una por AZ (viene del modulo networking)"
  type        = list(string)
}

variable "sg_backend_id" {
  description = "ID del security group del backend (viene del modulo security)"
  type        = string
}

variable "rds_endpoint" {
  description = "Endpoint host:puerto de RDS (viene del modulo data)"
  type        = string
}

variable "db_name" {
  description = "Nombre de la base de datos en RDS (viene del modulo data)"
  type        = string
}

variable "redis_primary_endpoint" {
  description = "Endpoint del nodo primario de Redis (viene del modulo data)"
  type        = string
}

variable "cloudfront_domain_name" {
  description = "Dominio de CloudFront, usado para armar CORS_ALLOWED_ORIGINS"
  type        = string
}
