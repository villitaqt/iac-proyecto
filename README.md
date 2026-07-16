# vivevinyls — Infraestructura (IaC)

Infraestructura como código (Terraform) de **vivevinyls**, una aplicación web de
tres capas desplegada en AWS (`us-east-1`).

## Arquitectura

Aplicación de tres capas detrás de un único dominio de CloudFront:

- **Frontend**: build estático de Vite (React) en un bucket S3 privado, servido
  por CloudFront vía Origin Access Control (OAC).
- **Backend**: contenedor Java/Spring Boot en ECS Fargate, detrás de un ALB, con
  auto scaling.
- **Datos**: PostgreSQL en RDS Multi-AZ + Redis en ElastiCache con réplica.

```
Usuario ──HTTPS──> CloudFront ──┬── (default)   ──> S3  (frontend, privado vía OAC)
                                └── (/api/*)     ──> ALB ──> ECS Fargate ──┬──> RDS PostgreSQL
                                                                          └──> ElastiCache Redis
```

CloudFront es la única puerta de entrada: el mismo dominio sirve el frontend y la
API (sin CORS de dominios distintos). El acceso a datos está encadenado por
security groups —internet → ALB → backend → datos— y RDS/Redis viven en subnets
privadas sin salida a internet.

### Estructura del repositorio

```
iac/
├── bootstrap/            Crea el bucket S3 + tabla DynamoDB del state remoto (se aplica UNA vez).
├── backend.tf            Configuración del backend remoto (S3).
├── providers.tf          Versiones fijadas + tags por defecto.
├── variables.tf          project, environment, aws_region.
├── main.tf               Cablea los 5 módulos entre sí.
├── outputs.tf            Todo lo que el proyecto expone.
├── modules/
│   ├── networking/       VPC, subnets, NAT, route tables, endpoint de S3.
│   ├── security/         KMS, security groups, secretos.
│   ├── data/             RDS PostgreSQL, ElastiCache Redis.
│   ├── compute/          ECR, IAM, ALB, ECS Fargate, auto scaling.
│   └── frontend/         S3, CloudFront, OAC.
└── .github/workflows/infra.yml   Pipeline: checkov → fmt → validate → plan → apply.
```

> Para un recorrido detallado del diseño y las decisiones tomadas, ver
> [`DISENO-INFRAESTRUCTURA.md`](DISENO-INFRAESTRUCTURA.md).

## Requisitos previos

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.7
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) con credenciales configuradas (`aws configure`)
- Una cuenta de AWS con permisos suficientes para crear los recursos.

## Cómo correr el proyecto

### 1. Bootstrap (solo la primera vez)

Crea el bucket S3 y la tabla DynamoDB donde vivirá el state remoto. Usa state
local y se aplica una única vez.

```bash
cd bootstrap
terraform init
terraform apply
```

Anotá el nombre del bucket que devuelve:

```bash
terraform output tfstate_bucket
```

### 2. Configurar el backend remoto

Editá [`backend.tf`](backend.tf) y reemplazá el valor de `bucket` con el nombre
exacto que devolvió el paso anterior (Terraform no permite variables en el bloque
`backend`, así que debe ir a mano).

### 3. Desplegar la infraestructura

Desde la raíz del repositorio:

```bash
cd ..
terraform init      # conecta con el backend remoto en S3
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

### 4. Pasos posteriores al apply

- **Token de MercadoPago**: el secreto se crea con un placeholder. Actualizá el
  valor real en Secrets Manager (consola/CLI); Terraform lo ignora en futuros
  applies.
- **Imagen del backend**: hacé push de la imagen a ECR (ver `ecr_repository_url`
  en los outputs) para que ECS Fargate pueda levantar la tarea.
- **Frontend**: subí el build de Vite (`dist/`) al bucket del frontend
  (`frontend_bucket`) e invalidá la caché de CloudFront
  (`frontend_distribution_id`).

### Outputs útiles

```bash
terraform output frontend_url             # URL pública del sitio
terraform output ecr_repository_url       # dónde pushear la imagen del backend
terraform output frontend_bucket          # bucket para el build del frontend
terraform output frontend_distribution_id # ID de CloudFront (para invalidar caché)
```

### Destruir el entorno

```bash
terraform destroy
```

> Nota: para agilizar la demo, RDS tiene `deletion_protection = false` y
> `skip_final_snapshot = true`, por lo que `destroy` borra la base sin dejar
> copia. En producción real ambos flags deberían invertirse.

## CI/CD

El workflow [`.github/workflows/infra.yml`](.github/workflows/infra.yml) corre en
cada push a `main` que toque archivos `.tf`/`.tfvars` (o manualmente vía
*workflow dispatch*):

1. **checkov** — análisis estático de seguridad (`soft_fail`, no bloquea).
2. **terraform** — `fmt -check` → `init` → `validate` → `plan` (subido como
   artifact) → `apply` (solo en push directo a `main`).

Requiere los secrets `AWS_ACCESS_KEY_ID` y `AWS_SECRET_ACCESS_KEY` en el
repositorio.
