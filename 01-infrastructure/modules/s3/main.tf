resource "aws_s3_bucket" "stripo_plugin" {
  bucket        = "${var.env_prefix}-stripo-plugin-storage"
  force_destroy = true
  tags          = var.tags
}



resource "aws_s3_bucket_server_side_encryption_configuration" "stripo_plugin" {
  bucket = aws_s3_bucket.stripo_plugin.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "stripo_plugin" {
  bucket = aws_s3_bucket.stripo_plugin.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "stripo_plugin" {
  bucket = aws_s3_bucket.stripo_plugin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.stripo_plugin.arn}/*"
      },
      {
        Sid       = "AllowECSTaskRoleAccess"
        Effect    = "Allow"
        Principal = {
          AWS = var.ecs_task_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.stripo_plugin.arn,
          "${aws_s3_bucket.stripo_plugin.arn}/*"
        ]
      }
    ]
  })
}

# Static website configuration
resource "aws_s3_bucket_website_configuration" "stripo_plugin" {
  bucket = aws_s3_bucket.stripo_plugin.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# IAM user for S3 access (for services that don't use ECS Task Role)
resource "aws_iam_user" "s3_access" {
  name = "${var.env_prefix}-s3-access-user"
  tags = var.tags
}

resource "aws_iam_access_key" "s3_access" {
  user = aws_iam_user.s3_access.name
}

resource "aws_iam_user_policy" "s3_access" {
  name = "${var.env_prefix}-s3-access-policy"
  user = aws_iam_user.s3_access.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.stripo_plugin.arn,
          "${aws_s3_bucket.stripo_plugin.arn}/*"
        ]
      }
    ]
  })
}
