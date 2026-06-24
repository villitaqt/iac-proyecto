# AZs disponibles en la región, tomadas dinámicamente: evita hardcodear
# nombres de AZ que pueden no existir o variar según la cuenta/región.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Necesario para que servicios como RDS y ECS resuelvan nombres DNS
  # internos correctamente.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project}-${var.environment}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-${var.environment}-igw"
  }
}

# --- Subnets ---

resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-${var.environment}-public-${local.azs[count.index]}"
  }
}

resource "aws_subnet" "private_app" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.project}-${var.environment}-private-app-${local.azs[count.index]}"
  }
}

resource "aws_subnet" "private_data" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_data_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.project}-${var.environment}-private-data-${local.azs[count.index]}"
  }
}

# --- NAT: uno por AZ, para que si una AZ cae no se pierda la salida a
# internet de las demás, y para evitar tráfico entre zonas (costo/latencia). ---

resource "aws_eip" "nat" {
  count  = var.az_count
  domain = "vpc"

  tags = {
    Name = "${var.project}-${var.environment}-nat-eip-${local.azs[count.index]}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = var.az_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project}-${var.environment}-nat-${local.azs[count.index]}"
  }

  depends_on = [aws_internet_gateway.main]
}

# --- Route tables ---

# Pública: una sola, compartida por todas las subnets públicas.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project}-${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Privada de app: una por AZ, cada una sale por el NAT de su MISMA zona,
# así no hay dependencia cruzada entre AZs si una falla.
resource "aws_route_table" "private_app" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.project}-${var.environment}-private-app-rt-${local.azs[count.index]}"
  }
}

resource "aws_route_table_association" "private_app" {
  count          = var.az_count
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

# Privada de datos: una por AZ, SIN ruta 0.0.0.0/0. RDS y Redis no
# necesitan ni deben poder salir a internet.
resource "aws_route_table" "private_data" {
  count  = var.az_count
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-${var.environment}-private-data-rt-${local.azs[count.index]}"
  }
}

resource "aws_route_table_association" "private_data" {
  count          = var.az_count
  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private_data[count.index].id
}

# S3 Gateway Endpoint: el tráfico a S3 (incluye pull de capas ECR, que
# se almacenan en S3) va directo por la red de AWS en vez de pasar por
# el NAT, lo que ahorra costo y no depende de salida a internet.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    aws_route_table.private_app[*].id,
    aws_route_table.private_data[*].id,
  )

  tags = {
    Name = "${var.project}-${var.environment}-s3-endpoint"
  }
}

data "aws_region" "current" {}
