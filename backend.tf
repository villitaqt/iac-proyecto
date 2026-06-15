# Backend remoto: state guardado en S3 con locking vía DynamoDB.
# Terraform NO permite usar variables aquí, así que "bucket" debe
# reemplazarse a mano con el nombre exacto que salió del bootstrap
# (terraform output tfstate_bucket).
terraform {
  backend "s3" {
    bucket         = "vivevinyls-tfstate-REEMPLAZAR"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "vivevinyls-tflock"
    encrypt        = true
  }
}
