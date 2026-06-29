variable "project" {
  description = "Nombre del proyecto, usado en nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue (prod, staging, dev, etc.)"
  type        = string
}

variable "private_data_subnet_ids" {
  description = "IDs de las subnets privadas de datos (2, una por AZ)"
  type        = list(string)
}

variable "sg_rds_id" {
  description = "ID del security group que solo permite trafico desde el backend hacia RDS"
  type        = string
}

variable "sg_redis_id" {
  description = "ID del security group que solo permite trafico desde el backend hacia Redis"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN de la CMK compartida, usada para cifrar RDS, Redis y el secreto de Redis"
  type        = string
}

variable "secret_db_arn" {
  description = "ARN del secreto vivevinyls/db con username y password ya generados"
  type        = string
}

variable "db_name" {
  description = "Nombre de la base de datos inicial en RDS"
  type        = string
  default     = "vivevinyls"
}

variable "db_instance_class" {
  description = "Clase de instancia de RDS"
  type        = string
  default     = "db.t4g.medium"
}

variable "db_allocated_storage" {
  description = "Almacenamiento inicial de RDS, en GB"
  type        = number
  default     = 20
}

variable "redis_node_type" {
  description = "Tipo de nodo de ElastiCache Redis"
  type        = string
  default     = "cache.t4g.small"
}
