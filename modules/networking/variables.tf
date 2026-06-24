variable "project" {
  description = "Nombre del proyecto, usado en nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue (prod, staging, dev, etc.)"
  type        = string
}

variable "vpc_cidr" {
  description = "Rango CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Cantidad de AZs a usar (mínimo 2 para alta disponibilidad)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "az_count debe ser al menos 2 para que haya redundancia entre zonas."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDRs para las subnets públicas, una por AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDRs para las subnets privadas de aplicación, una por AZ"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_data_subnet_cidrs" {
  description = "CIDRs para las subnets privadas de datos, una por AZ"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}
