# Grupo de subnets: RDS y Redis viven solo en las subnets privadas de
# datos, sin salida a internet (ver modules/networking).
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_data_subnet_ids

  tags = {
    Name = "${var.project}-${var.environment}-db-subnet-group"
  }
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-redis-subnet-group"
  subnet_ids = var.private_data_subnet_ids
}

# El usuario/password de la base de datos ya se generaron en el
# commit de security (vivevinyls/db); aca solo se leen, nunca se
# generan de nuevo.
data "aws_secretsmanager_secret_version" "db" {
  secret_id = var.secret_db_arn
}

locals {
  db_credentials = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string)
}

resource "aws_db_instance" "main" {
  identifier = "${var.project}-${var.environment}-db"

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  db_name  = var.db_name
  username = local.db_credentials.username
  password = local.db_credentials.password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.sg_rds_id]

  # Multi-AZ: si la instancia primaria falla, RDS promueve
  # automaticamente la replica en la otra AZ.
  multi_az = true

  backup_retention_period = 7

  # En fase de pruebas: se necesita poder destruir el ambiente rapido
  # antes de la demo final, sin snapshot final ni proteccion.
  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Name = "${var.project}-${var.environment}-db"
  }
}

# Token de autenticacion de Redis. Se genera aca (no viene de un
# secreto previo, a diferencia de la password de RDS) y se guarda en
# Secrets Manager para que el backend lo pueda leer despues.
resource "random_password" "redis_auth" {
  length = 32
  # ElastiCache no acepta '@', '"', ni '/' en el auth token.
  override_special = "!#$%^&*()-_=+"
}

resource "aws_secretsmanager_secret" "redis" {
  name       = "vivevinyls/redis"
  kms_key_id = var.kms_key_arn

  tags = {
    Name = "${var.project}-${var.environment}-redis-secret"
  }
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    auth_token = random_password.redis_auth.result
  })
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project}-${var.environment}-redis"
  description          = "Redis cache for the vivevinyls backend"

  engine         = "redis"
  engine_version = "7.1"
  node_type      = var.redis_node_type
  port           = 6379

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.sg_redis_id]

  # 1 primario + 1 replica en otra AZ, con failover automatico si el
  # primario falla.
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true

  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth.result

  tags = {
    Name = "${var.project}-${var.environment}-redis"
  }
}
