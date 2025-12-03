# Terraform/OpenTofu configuration for hosting a simple static website on AWS.
# It creates:
# - An S3 bucket to store your website files (HTML/CSS/JS)
# - A CloudFront CDN to serve the site globally with HTTPS
# - Secure settings (encryption, access control, caching, headers)
# You only need AWS credentials and a region. Apply with: tofu init && tofu apply

terraform {
  # Use Terraform/OpenTofu 1.14 or newer
  required_version = ">= 1.14.0"
  required_providers {
    # AWS provider to talk to Amazon Web Services
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.24"
    }
    # Random provider to generate a short unique suffix for names
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}

provider "aws" {
  # Region where resources will be created (set via var.aws_region)
  region = var.aws_region

  # Default tags applied to every AWS resource for tracking
  default_tags {
    tags = {
      Project     = "typing-app"
      Environment = var.environment
      ManagedBy   = "opentofu"
    }
  }
}

# Generate a short random hex string used in resource names to avoid collisions
resource "random_id" "suffix" {
  byte_length = 4
}

# Pick the bucket name: if user provides one, use it; otherwise generate a unique one
# locals is used to define local variables
locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : "typing-app-${random_id.suffix.hex}"
}

# Create the S3 bucket that holds the website files
resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name
}

# Set bucket ownership so the bucket owner controls uploaded objects
resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Block all direct public access to the bucket.
# Site will be served through CloudFront only.
resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning to keep previous versions of files (helps rollback)
resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt all files at rest using AES-256 (server-side encryption)
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Create a CloudFront Origin Access Control (OAC) so CloudFront can read from S3 securely
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${local.bucket_name}-oac"
  description                       = "OAC for S3 bucket ${local.bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Create the CloudFront distribution (CDN) that serves the website globally over HTTPS
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  comment             = "Typing app distribution"
  is_ipv6_enabled     = true
  http_version        = "http3"          # Use modern HTTP/3 for performance
  price_class         = "PriceClass_100" # Limit to cheapest regions; can raise for wider coverage
  wait_for_deployment = true             # Wait until the CDN is ready before finishing apply

  # Connect the CDN to the S3 bucket as its origin
  origin {
    domain_name = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id   = "s3-origin"

    # Use OAC for secure, signed requests from CloudFront to S3
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  # Default caching behavior: only allow read methods; compress responses; use cache & security policies
  default_cache_behavior {
    target_origin_id           = "s3-origin"
    viewer_protocol_policy     = "redirect-to-https" # Force HTTPS
    compress                   = true
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = aws_cloudfront_cache_policy.static.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # Handle SPA routing: serve index.html for 404s so client-side router works
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }

  # No geographic restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Use CloudFront’s default certificate on the cloudfront.net domain
  # To use a custom domain, you would attach an ACM certificate here.
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# IAM policy: allow CloudFront (this specific distribution) to read objects from the bucket
data "aws_iam_policy_document" "cf_access" {
  statement {
    sid       = "AllowCloudFrontRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    # Restrict access so only this CloudFront distribution’s ARN is allowed
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

# Attach the policy to the bucket
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.cf_access.json
}

# Enable static website configuration in S3 (used here for SPA routing fallback)
# Note: We still block public access; CloudFront is the only way in.
resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
}

# Upload your website files to the S3 bucket.
# These three resources push index.html, script.js, and styles.css from the project root.
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  source       = "${path.module}/../index.html"
  content_type = "text/html"
  source_hash  = filemd5("${path.module}/../index.html") # Triggers update when file changes
}

resource "aws_s3_object" "script" {
  bucket       = aws_s3_bucket.site.id
  key          = "script.js"
  source       = "${path.module}/../script.js"
  content_type = "application/javascript"
  source_hash  = filemd5("${path.module}/../script.js")
}

resource "aws_s3_object" "styles" {
  bucket       = aws_s3_bucket.site.id
  key          = "styles.css"
  source       = "${path.module}/../styles.css"
  content_type = "text/css"
  source_hash  = filemd5("${path.module}/../styles.css")
}

# Define how CloudFront caches content (TTL) and what request parts affect the cache key
resource "aws_cloudfront_cache_policy" "static" {
  name        = "${local.bucket_name}-static-cache"
  default_ttl = 86400  # 1 day
  max_ttl     = 604800 # 7 days
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    headers_config { header_behavior = "none" }
    cookies_config { cookie_behavior = "none" }
    query_strings_config { query_string_behavior = "none" }
  }
}

# Add common security headers to responses
resource "aws_cloudfront_response_headers_policy" "security" {
  name = "${local.bucket_name}-headers"

  security_headers_config {
    content_security_policy {
      override                = true
      content_security_policy = "default-src 'self'; style-src 'self' 'unsafe-inline';"
    }
    content_type_options { override = true }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "no-referrer"
      override        = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true
      preload                    = true
    }
    xss_protection {
      mode_block = true
      override   = true
      protection = true
    }
  }
}

# Show useful outputs after deployment
output "bucket_name" { value = aws_s3_bucket.site.id }
output "cloudfront_domain" { value = aws_cloudfront_distribution.cdn.domain_name }
