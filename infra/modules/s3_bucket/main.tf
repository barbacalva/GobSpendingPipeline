resource "aws_s3_bucket" "this" {
  bucket        = var.name
  force_destroy = false

  tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "this" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.expire_after_days != null ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-objects"

    filter {}

    status = "Enabled"

    expiration {
      days = var.expire_after_days
    }
  }
}