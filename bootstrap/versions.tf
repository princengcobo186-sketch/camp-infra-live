terraform {
  # >= 1.10 for native S3 state locking (use_lockfile), so no DynamoDB table is needed.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # This layer creates the bucket that holds all other state, so its first apply used local state
  # and was then migrated here. The bucket name contains the account ID and this repository is
  # public, so the bucket is passed at init time (-backend-config=bucket=...), not committed.
  #
  # The bootstrap/ key sits outside every <env>/ prefix. No CI role can write it, and each CI
  # role's state policy explicitly denies reading it (see ci_access.tf).
  backend "s3" {
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-north-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Component = "bootstrap"
    }
  }
}
