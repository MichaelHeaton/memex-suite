terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Store state locally for the bootstrap module — it has no chicken-and-egg
  # dependency on a remote bucket (it creates its own SAM artifacts bucket,
  # not a Terraform state bucket). Commit terraform.tfstate after first apply.
  # Optionally migrate to S3 backend later using the platform-bootstrap bucket.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project    = "memex-suite"
      managed-by = "terraform"
    }
  }
}
