variable "aws_account_id" {
  description = "Your AWS account ID (12 digits, no hyphens)"
  type        = string
}

variable "aws_region" {
  description = "Primary AWS region for memex-suite resources"
  type        = string
  default     = "us-east-1"
}

variable "github_org" {
  description = "GitHub org or username that owns the memex-suite repo"
  type        = string
  default     = "MichaelHeaton"
}

variable "sam_bucket_name" {
  description = "S3 bucket for SAM deployment artifacts (must be globally unique)"
  type        = string
}
