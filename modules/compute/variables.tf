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
