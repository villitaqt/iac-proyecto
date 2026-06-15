# Bootstrap: crea el bucket S3 y la tabla DynamoDB que usará el backend
# remoto del proyecto principal. Este mini-proyecto usa state LOCAL
# (no puede referenciar un backend remoto que todavía no existe) y se
# aplica UNA SOLA VEZ, antes de tocar el proyecto principal.

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
  region = "us-east-1"
}

# Sufijo aleatorio para que los nombres de bucket sean únicos globalmente.
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "vivevinyls-tfstate-${random_id.suffix.hex}"
}

# Versioning: permite recuperar un state anterior si algo sale mal.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Cifrado en reposo: el state puede contener datos sensibles (IDs, ARNs, etc.).
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# El bucket de state nunca debe ser público.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Tabla de locking: evita que dos "terraform apply" corran al mismo tiempo
# y corrompan el state.
resource "aws_dynamodb_table" "tflock" {
  name         = "vivevinyls-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "tfstate_bucket" {
  description = "Nombre del bucket S3 para el state remoto"
  value       = aws_s3_bucket.tfstate.bucket
}

output "tflock_table" {
  description = "Nombre de la tabla DynamoDB para el locking"
  value       = aws_dynamodb_table.tflock.name
}
