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
