output "bucket_name" {
  description = "Name of the S3 bucket hosting the site"
  value       = aws_s3_bucket.site.id
}

output "cloudfront_domain" {
  description = "CloudFront domain to access the site"
  value       = aws_cloudfront_distribution.cdn.domain_name
}
