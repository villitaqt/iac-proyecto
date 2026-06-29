# Bucket S3 que aloja los archivos estáticos del build de Vite.
# No es público: solo CloudFront puede leerlo, vía Origin Access Control.
resource "aws_s3_bucket" "frontend" {
  bucket = "vivevinyls-frontend-${var.bucket_suffix}"
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# OAC: reemplaza a la OAI legacy, permite que CloudFront firme las
# peticiones a S3 sin exponer el bucket públicamente.
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project}-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"

  # PriceClass_All incluye el edge de Lima (Sudamérica); las clases
  # más baratas no cubren esa región.
  price_class = "PriceClass_All"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "frontend-s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # El ALB solo escucha HTTP (sin certificado propio): CloudFront
  # sigue siendo quien termina TLS del lado del usuario, y el tramo
  # CloudFront -> ALB va sobre HTTP en el puerto 80.
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "backend-alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "frontend-s3-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  # Todo lo que empiece con /api/ va al backend (ALB) en vez del
  # bucket S3, cerrando el circuito frontend-backend detras del mismo
  # dominio de CloudFront.
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    target_origin_id = "backend-alb-origin"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    # CachingDisabled (managed): las respuestas de la API nunca se
    # cachean, cada request llega siempre al backend.
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # AllViewerExceptHostHeader (managed): reenvia todos los headers
    # del viewer, incluido Authorization, que CloudFront descarta por
    # defecto y que el backend necesita para validar el JWT.
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"

    viewer_protocol_policy = "redirect-to-https"
  }

  # Rutas de una SPA (React Router, etc.): si S3 responde 403/404 porque
  # el archivo no existe, servimos index.html igual con código 200 para
  # que el router del frontend maneje la ruta.
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Sin dominio propio: usamos el certificado *.cloudfront.net por defecto.
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Bucket policy: solo esta distribución de CloudFront (identificada por
# su ARN) puede leer objetos del bucket.
data "aws_iam_policy_document" "frontend" {
  statement {
    sid       = "AllowCloudFrontServicePrincipal"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend.json
}
