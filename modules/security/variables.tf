variable "project" {
  description = "Nombre del proyecto, usado en nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue (prod, staging, dev, etc.)"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC (viene del módulo networking)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR de la VPC (viene del módulo networking)"
  type        = string
}
