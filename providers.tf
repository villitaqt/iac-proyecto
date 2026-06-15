# Versión de Terraform y del provider AWS fijadas para evitar sorpresas
# por cambios de comportamiento entre versiones.
terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # default_tags aplica estas etiquetas a todo recurso que soporte tags,
  # sin tener que repetirlas en cada resource.
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
    }
  }
}
