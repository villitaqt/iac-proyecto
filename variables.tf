variable "aws_region" {
  description = "Región de AWS donde se despliega la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
  default     = "vivevinyls"
}

variable "environment" {
  description = "Entorno de despliegue (prod, staging, dev, etc.)"
  type        = string
  default     = "prod"
}
