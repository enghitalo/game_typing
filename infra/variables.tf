variable "aws_region" {
  description = "AWS region to deploy S3 bucket"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Optional: predefine an S3 bucket name (must be globally unique). If empty, a random suffix is added."
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name for resource tagging"
  type        = string
  default     = "production"
}
