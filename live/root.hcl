# Root Terragrunt config. Every stack includes this file, so the backend and provider below are
# generated once here and never written per stack or per environment.
#
# Two kinds of environment share this file:
#   local                 - Kind cluster on the developer machine. Local state, no AWS provider,
#                           no credentials, $0. Exists so the Argo CD bootstrap module is
#                           exercised on Kind with exactly the code path EKS uses.
#   shared, dev, staging, - AWS. S3 state with native locking, provider pinned to one account.
#   prod

# Terragrunt prefers OpenTofu when both are installed. This repo pins Terraform in
# .tool-versions, so name it explicitly rather than rely on binary discovery.
terraform_binary             = "terraform"
terraform_version_constraint = ">= 1.10"

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  project     = "camp"
  environment = local.env_vars.locals.environment
  is_local    = local.environment == "local"

  # Fails (regex mismatch) if a stack lives outside its own environment directory, or env.hcl
  # names a different environment than the directory it sits in. State keys come from the path
  # and CI IAM scopes state access by that prefix, so a mismatch must not run.
  stack_path = path_relative_to_include()
  _env_guard = regex("^${local.environment}/", local.stack_path)

  # AWS-only values. local/env.hcl defines neither. HCL evaluates both arms of a conditional,
  # so the placeholder must be a string (null cannot be interpolated). It never reaches a file:
  # the generate blocks that use it are disabled or take the other arm for local.
  region     = try(local.env_vars.locals.region, "unused-in-local")
  account_id = try(local.env_vars.locals.account_id, "unused-in-local")

  # Backend bodies for generate "backend" below. generate (not remote_state) because the two
  # backends take different config shapes and remote_state cannot switch between them.
  # bootstrap/ owns the bucket; nothing here creates or reconfigures it.
  # State sits beside the stack (gitignored), not in .terragrunt-cache, which is disposable:
  # losing local state would orphan the Argo CD install in the Kind cluster.
  backend_local = <<-EOF
    terraform {
      backend "local" {
        path = "${get_terragrunt_dir()}/terraform.tfstate"
      }
    }
  EOF

  backend_s3 = <<-EOF
    terraform {
      backend "s3" {
        # Created by bootstrap/. Name must match bootstrap/state.tf.
        bucket = "${local.project}-tfstate-${local.account_id}-${local.region}"

        # <env>/<stack>/terraform.tfstate. The <env>/ prefix is the IAM isolation boundary.
        key    = "${local.stack_path}/terraform.tfstate"
        region = "${local.region}"

        encrypt      = true
        use_lockfile = true # S3 native locking; no DynamoDB table.
      }
    }
  EOF
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = local.is_local ? local.backend_local : local.backend_s3
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  disable   = local.is_local

  contents = <<-EOF
    provider "aws" {
      region              = "${local.region}"
      allowed_account_ids = ["${local.account_id}"]

      default_tags {
        tags = {
          Project     = "${local.project}"
          Environment = "${local.environment}"
          Stack       = "${local.stack_path}"
          ManagedBy   = "terragrunt"
          Repository  = "camp-infra-live"
        }
      }
    }
  EOF
}

# Inputs every module receives. Module-specific inputs live in _envcommon/ and each stack's
# terragrunt.hcl.
inputs = {
  project     = local.project
  environment = local.environment
}
