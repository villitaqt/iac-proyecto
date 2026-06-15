# Sufijo para nombres de bucket únicos globalmente en este proyecto.
resource "random_id" "suffix" {
  byte_length = 4
}

module "frontend" {
  source        = "./modules/frontend"
  project       = var.project
  bucket_suffix = random_id.suffix.hex
}
