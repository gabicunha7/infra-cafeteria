# ── Buckets de tratamento de dados 
resource "random_string" "bucket_suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "aws_s3_bucket" "data" {
  for_each = toset(var.s3_bucket_names)

  bucket = "${var.project_name}-${each.value}-${random_string.bucket_suffix.result}"

  tags = {
    Name  = "${var.project_name}-${each.value}"
    Stage = each.value
  }
}

resource "aws_s3_bucket_versioning" "data" {
  for_each = aws_s3_bucket.data

  bucket = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  for_each = aws_s3_bucket.data

  bucket = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Por padrao os buckets ficam privados, sem acesso externo.
resource "aws_s3_bucket_public_access_block" "data" {
  for_each = aws_s3_bucket.data

  bucket                  = each.value.id
  block_public_acls       = !var.s3_buckets_public
  ignore_public_acls      = !var.s3_buckets_public
  block_public_policy     = !var.s3_buckets_public
  restrict_public_buckets = !var.s3_buckets_public
}

resource "aws_s3_bucket_policy" "public_rw" {
  for_each = var.s3_buckets_public ? aws_s3_bucket.data : {}

  bucket = each.value.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadWriteAccess"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
      Resource  = "${each.value.arn}/*"
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.data]
}
