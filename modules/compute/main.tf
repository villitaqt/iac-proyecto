# --- ECR ---

resource "aws_ecr_repository" "backend" {
  name = "${var.project}-backend"

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

# --- ECS ---

data "aws_region" "current" {}

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.environment}"

  # Metricas a nivel de servicio/tarea en CloudWatch, utiles despues
  # para armar dashboards en Grafana.
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project}-backend"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn

  tags = {
    Name = "${var.project}-${var.environment}-backend-logs"
  }
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project}-backend"
  requires_compatibilities = ["FARGATE"]
  # awsvpc: obligatorio en Fargate, le da a cada tarea su propia ENI
  # con IP privada dentro de la VPC.
  network_mode = "awsvpc"
  cpu          = "1024"
  memory       = "2048"

  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name  = "backend"
      image = "${aws_ecr_repository.backend.repository_url}:latest"

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      # Valores no sensibles: van planos como variables de entorno.
      environment = [
        {
          name  = "POSTGRES_URL"
          value = "jdbc:postgresql://${var.rds_endpoint}/${var.db_name}"
        },
        {
          name  = "REDIS_HOST"
          value = var.redis_primary_endpoint
        },
        {
          name  = "REDIS_PORT"
          value = "6379"
        },
        {
          name  = "REDIS_SSL_ENABLED"
          value = "true"
        },
        {
          name  = "CORS_ALLOWED_ORIGINS"
          value = "https://${var.cloudfront_domain_name}"
        },
      ]

      # Valores sensibles: ECS los inyecta directo desde Secrets
      # Manager al arrancar la tarea, nunca quedan en el plan/state
      # en texto plano ni en la definicion de la tarea.
      secrets = [
        {
          name      = "POSTGRES_USER"
          valueFrom = "${var.secret_db_arn}:username::"
        },
        {
          name      = "POSTGRES_PASSWORD"
          valueFrom = "${var.secret_db_arn}:password::"
        },
        {
          name      = "JWT_SECRET"
          valueFrom = "${var.secret_jwt_arn}:secret::"
        },
        {
          name      = "REDIS_PASSWORD"
          valueFrom = "${var.secret_redis_arn}:auth_token::"
        },
        {
          name      = "MP_ACCESS_TOKEN"
          valueFrom = "${var.secret_mercadopago_arn}:access_token::"
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "backend"
        }
      }

      # Requisito de ECS Exec: sin esto, "aws ecs execute-command" no
      # puede abrir una sesion dentro del contenedor.
      linuxParameters = {
        initProcessEnabled = true
      }
    }
  ])

  tags = {
    Name = "${var.project}-${var.environment}-backend-task"
  }
}

resource "aws_ecs_service" "backend" {
  name            = "backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.sg_backend_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8080
  }

  enable_execute_command = true

  # Si un deploy nuevo no levanta sano, ECS revierte solo al ultimo
  # task definition que funcionaba, en vez de dejar el servicio caido.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # El listener tiene que existir antes de registrar el servicio,
  # para que el target group ya este colgado del ALB.
  depends_on = [aws_lb_listener.http]

  tags = {
    Name = "${var.project}-${var.environment}-backend-service"
  }
}

# --- Auto Scaling ---

resource "aws_appautoscaling_target" "backend" {
  min_capacity       = 2
  max_capacity       = 20
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Target tracking: ECS ajusta el desired_count solo para mantener el
# uso de CPU promedio del servicio cerca del 60%.
resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.project}-${var.environment}-backend-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.backend.resource_id
  scalable_dimension = aws_appautoscaling_target.backend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.backend.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 60
  }
}
