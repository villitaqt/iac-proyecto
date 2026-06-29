# Sufijo para nombres de bucket únicos globalmente en este proyecto.
resource "random_id" "suffix" {
  byte_length = 4
}

module "frontend" {
  source        = "./modules/frontend"
  project       = var.project
  bucket_suffix = random_id.suffix.hex
}

module "networking" {
  source      = "./modules/networking"
  project     = var.project
  environment = var.environment
}

module "security" {
  source      = "./modules/security"
  project     = var.project
  environment = var.environment
  vpc_id      = module.networking.vpc_id
  vpc_cidr    = module.networking.vpc_cidr
}

module "data" {
  source                  = "./modules/data"
  project                 = var.project
  environment             = var.environment
  private_data_subnet_ids = module.networking.private_data_subnet_ids
  sg_rds_id               = module.security.sg_rds_id
  sg_redis_id             = module.security.sg_redis_id
  kms_key_arn             = module.security.kms_key_arn
  secret_db_arn           = module.security.secret_db_arn
}

module "compute" {
  source                 = "./modules/compute"
  project                = var.project
  environment            = var.environment
  kms_key_arn            = module.security.kms_key_arn
  secret_db_arn          = module.security.secret_db_arn
  secret_jwt_arn         = module.security.secret_jwt_arn
  secret_redis_arn       = module.data.secret_redis_arn
  secret_mercadopago_arn = module.security.secret_mercadopago_arn
}
