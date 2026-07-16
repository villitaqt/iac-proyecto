# Sufijo para nombres de bucket únicos globalmente en este proyecto.
resource "random_id" "suffix" {
  byte_length = 4
}

module "frontend" {
  source        = "./modules/frontend"
  project       = var.project
  bucket_suffix = random_id.suffix.hex
  alb_dns_name  = module.compute.alb_dns_name
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
  vpc_id                 = module.networking.vpc_id
  public_subnet_ids      = module.networking.public_subnet_ids
  sg_alb_id              = module.security.sg_alb_id
  private_app_subnet_ids = module.networking.private_app_subnet_ids
  sg_backend_id          = module.security.sg_backend_id
  rds_endpoint           = module.data.rds_endpoint
  db_name                = module.data.rds_database_name
  redis_primary_endpoint = module.data.redis_primary_endpoint
  cloudfront_domain_name = module.frontend.domain_name
}
