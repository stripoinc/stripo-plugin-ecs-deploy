output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.stripo_plugin.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.stripo_plugin.arn
}

output "bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.stripo_plugin.region
}

output "access_key_id" {
  description = "Access Key ID for S3 access"
  value       = aws_iam_access_key.s3_access.id
  sensitive   = true
}

output "secret_access_key" {
  description = "Secret Access Key for S3 access"
  value       = aws_iam_access_key.s3_access.secret
  sensitive   = true
}

output "base_download_url" {
  description = "Base download URL for S3 objects"
  value       = "https://${aws_s3_bucket.stripo_plugin.bucket}.s3.${aws_s3_bucket.stripo_plugin.region}.amazonaws.com"
}

output "website_endpoint" {
  description = "S3 website endpoint"
  value       = aws_s3_bucket_website_configuration.stripo_plugin.website_endpoint
}

output "website_domain" {
  description = "S3 website domain"
  value       = aws_s3_bucket_website_configuration.stripo_plugin.website_domain
}
