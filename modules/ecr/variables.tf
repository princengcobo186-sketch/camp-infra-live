variable "project" {
  description = "Project name."
  type        = string
}

variable "environment" {
  description = "Environment that owns the repository. Account-level registries use shared."
  type        = string
}

variable "repository_name" {
  description = "Repository name, namespaced by project (for example camp/payment-service)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(?:[._-][a-z0-9]+)*(?:/[a-z0-9]+(?:[._-][a-z0-9]+)*)*$", var.repository_name))
    error_message = "repository_name must be a valid ECR repository name, lowercase, for example camp/payment-service."
  }
}

variable "untagged_expiry_days" {
  description = "Untagged images are expired after this many days since they were pushed."
  type        = number
  default     = 7
}

variable "keep_last_images" {
  description = "Keep at most this many images in the repository. Older images are expired."
  type        = number
  default     = 30
}
