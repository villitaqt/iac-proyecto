data "aws_caller_identity" "current" {}

# --- KMS ---

# CMK única para cifrar RDS, Secrets Manager, logs y objetos S3
# sensibles. Una sola key simplifica la administración; si en el
# futuro se necesita aislar permisos por servicio, se puede separar.
resource "aws_kms_key" "main" {
  description             = "CMK de ${var.project}-${var.environment} para RDS, Secrets Manager, S3 y CloudWatch Logs"
  enable_key_rotation     = true
  rotation_period_in_days = 365

  policy = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project}-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}

data "aws_iam_policy_document" "kms" {
  # La cuenta root mantiene control total: sin esto, es posible
  # perder acceso administrativo a la key (ej. si se borran los roles
  # que la usan).
  statement {
    sid       = "AllowAccountAdmin"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # Los servicios de AWS que van a cifrar datos con esta key (RDS,
  # Secrets Manager, S3, CloudWatch Logs) necesitan poder usarla para
  # cifrar/descifrar en nombre de la cuenta.
  statement {
    sid = "AllowAWSServicesToUseKey"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    principals {
      type = "Service"
      identifiers = [
        "rds.amazonaws.com",
        "secretsmanager.amazonaws.com",
        "s3.amazonaws.com",
        "logs.amazonaws.com",
      ]
    }
  }
}

# --- Security Groups ---
# Cada SG solo abre lo mínimo que necesita y referencia otros SGs por
# id en vez de CIDRs, para que el acceso quede encadenado (defensa en
# capas): internet -> ALB -> backend -> datos, nunca un salto directo.

resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "SG del ALB: único punto que recibe tráfico de internet"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-alb-sg"
  }
}

resource "aws_security_group" "backend" {
  name        = "${var.project}-${var.environment}-backend-sg"
  description = "SG del backend: solo acepta tráfico del ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-backend-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.environment}-rds-sg"
  description = "SG de RDS: solo acepta tráfico del backend"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-rds-sg"
  }
}

resource "aws_security_group" "redis" {
  name        = "${var.project}-${var.environment}-redis-sg"
  description = "SG de Redis: solo acepta tráfico del backend"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-redis-sg"
  }
}

# Las reglas van como recursos separados (no bloques inline) para
# evitar un ciclo de dependencias: backend necesita salir hacia rds/
# redis, y rds/redis necesitan recibir del backend. Con reglas
# independientes, los SGs se crean primero y las reglas se agregan
# después sin que ningún SG dependa del otro para existir.

# ALB: entra HTTPS (y HTTP como fallback sin certificado ACM aún).
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS desde internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP desde internet (fallback mientras no hay certificado ACM)"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "El ALB necesita reenviar tráfico al backend en cualquier puerto"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Backend: solo recibe del ALB, y solo sale hacia RDS, Redis, e
# internet por 443 (APIs externas como MercadoPago, ECR, Secrets
# Manager, todo vía NAT).
resource "aws_vpc_security_group_ingress_rule" "backend_from_alb" {
  security_group_id            = aws_security_group.backend.id
  description                  = "Tráfico de la app, solo desde el ALB"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "backend_to_rds" {
  security_group_id            = aws_security_group.backend.id
  description                  = "Postgres hacia RDS"
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "backend_to_redis" {
  security_group_id            = aws_security_group.backend.id
  description                  = "Redis hacia el cache"
  referenced_security_group_id = aws_security_group.redis.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "backend_https_out" {
  security_group_id = aws_security_group.backend.id
  description       = "HTTPS saliente vía NAT: MercadoPago, ECR, Secrets Manager"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# RDS y Redis: solo reciben del backend, sin salida (no necesitan
# iniciar conexiones hacia afuera).
resource "aws_vpc_security_group_ingress_rule" "rds_from_backend" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Postgres, solo desde el backend"
  referenced_security_group_id = aws_security_group.backend.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_backend" {
  security_group_id            = aws_security_group.redis.id
  description                  = "Redis, solo desde el backend"
  referenced_security_group_id = aws_security_group.backend.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}

# --- Secrets Manager ---

resource "random_password" "db" {
  length = 24
  # RDS no acepta '/', '@', '"', ni espacios en la contraseña maestra.
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

resource "random_password" "jwt" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "db" {
  name       = "vivevinyls/db"
  kms_key_id = aws_kms_key.main.arn

  tags = {
    Name = "${var.project}-${var.environment}-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = "vivevinyls_app"
    password = random_password.db.result
  })
}

resource "aws_secretsmanager_secret" "jwt" {
  name       = "vivevinyls/jwt"
  kms_key_id = aws_kms_key.main.arn

  tags = {
    Name = "${var.project}-${var.environment}-jwt-secret"
  }
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({
    secret = random_password.jwt.result
  })
}

# El token de MercadoPago es una credencial externa real: no se
# genera con Terraform, se deja un placeholder y se actualiza a mano
# después del apply (ver comando aws al final).
resource "aws_secretsmanager_secret" "mercadopago" {
  name       = "vivevinyls/mercadopago"
  kms_key_id = aws_kms_key.main.arn

  tags = {
    Name = "${var.project}-${var.environment}-mercadopago-secret"
  }
}

resource "aws_secretsmanager_secret_version" "mercadopago" {
  secret_id = aws_secretsmanager_secret.mercadopago.id
  secret_string = jsonencode({
    access_token = "REEMPLAZAR-EN-CONSOLA"
  })

  # Evita que un futuro "terraform apply" pise el valor real que se
  # cargue manualmente en consola/CLI con este placeholder otra vez.
  lifecycle {
    ignore_changes = [secret_string]
  }
}
