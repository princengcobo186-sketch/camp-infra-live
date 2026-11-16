variable "project" {
  description = "Project name, used as a prefix for resource names."
  type        = string
  default     = "camp"
}

variable "region" {
  description = "AWS region for the state bucket and all resources."
  type        = string
  default     = "eu-north-1"
}

variable "account_id" {
  description = "Expected AWS account ID. Required with no default so the account is never discovered implicitly; the provider fails closed on any other account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "environments" {
  description = "Environments that get CI plan and apply identities and isolated state access. Phase 2 creates only shared; staging, dev and prod are added when they are first applied."
  type        = set(string)
  default     = ["shared"]
}

variable "ecr_repository_name" {
  description = "ECR repository the release pipeline pushes to. Its name is the only resource the push identity can write to."
  type        = string
  default     = "camp/payment-service"
}

variable "state_noncurrent_version_days" {
  description = "Days to keep superseded state object versions (the rollback path for a bad apply)."
  type        = number
  default     = 90
}
