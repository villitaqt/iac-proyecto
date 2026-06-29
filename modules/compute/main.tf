# --- ECR ---

resource "aws_ecr_repository" "backend" {
  name = "vivevinyls-backend"

  # MUTABLE para poder re-pushear el tag :latest en cada deploy.
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = {
    Name = "${var.project}-${var.environment}-backend-ecr"
  }
}

# Solo se conservan las ultimas 10 imagenes, para no acumular costo
# de storage con builds viejos.
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Conservar solo las ultimas 10 imagenes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# --- IAM ---

# Trust policy compartido: solo ECS Tasks puede asumir estos roles.
data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Rol de ejecucion: lo usa el agente de ECS para arrancar el
# contenedor (pull de ECR, logs, y leer los secretos que se inyectan
# como variables de entorno).
resource "aws_iam_role" "task_execution" {
  name               = "${var.project}-${var.environment}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json

  tags = {
    Name = "${var.project}-${var.environment}-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Ademas de la managed policy, el rol de ejecucion necesita leer los
# 4 secretos puntuales que usa el backend (nada mas, nada de
# "secretsmanager:*" sobre todo el account).
data "aws_iam_policy_document" "task_execution_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      var.secret_db_arn,
      var.secret_jwt_arn,
      var.secret_redis_arn,
      var.secret_mercadopago_arn,
    ]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "task_execution_secrets" {
  name   = "${var.project}-${var.environment}-task-execution-secrets"
  role   = aws_iam_role.task_execution.id
  policy = data.aws_iam_policy_document.task_execution_secrets.json
}

# Rol de la tarea: lo usa el codigo de la aplicacion en si. Por ahora
# solo necesita los permisos minimos para habilitar ECS Exec (poder
# entrar a una shell del contenedor para debug), sin acceso a S3 ni
# a ningun otro servicio.
resource "aws_iam_role" "task_role" {
  name               = "${var.project}-${var.environment}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json

  tags = {
    Name = "${var.project}-${var.environment}-task-role"
  }
}

data "aws_iam_policy_document" "task_role_exec" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    # Estas acciones de SSM Messages no soportan permisos a nivel de
    # recurso: AWS exige "*" aqui.
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_role_exec" {
  name   = "${var.project}-${var.environment}-task-role-exec"
  role   = aws_iam_role.task_role.id
  policy = data.aws_iam_policy_document.task_role_exec.json
}

# --- ALB ---

resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [var.sg_alb_id]

  tags = {
    Name = "${var.project}-${var.environment}-alb"
  }
}

# target_type = "ip" porque Fargate no tiene instancias EC2 propias
# que registrar; el target es la IP de la ENI de cada tarea.
resource "aws_lb_target_group" "backend" {
  name        = "${var.project}-${var.environment}-backend-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project}-${var.environment}-backend-tg"
  }
}

# Listener solo HTTP: no hay dominio propio todavia, asi que no hay
# certificado ACM que emitir. CloudFront ya termina TLS del lado del
# usuario; el tramo CloudFront -> ALB va sobre HTTP en el puerto 80.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
