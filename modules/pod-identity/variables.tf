variable "project" {
  description = "Project name."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster the association is made in."
  type        = string
}

variable "name" {
  description = "Short role name, for example aws-load-balancer-controller. The role is named <project>-<environment>-<name>."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{1,40}$", var.name))
    error_message = "name must be 1 to 40 lowercase letters, digits or hyphens."
  }
}

variable "namespace" {
  description = "Kubernetes namespace of the ServiceAccount. The namespace and ServiceAccount name are the contract with the gitops repo: renaming either is a breaking change."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace))
    error_message = "namespace must be a valid Kubernetes namespace name."
  }
}

variable "service_account" {
  description = "Kubernetes ServiceAccount name that receives these permissions."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$", var.service_account))
    error_message = "service_account must be a valid Kubernetes ServiceAccount name."
  }
}

variable "inline_policy_json" {
  description = "Least-privilege policy for this workload as JSON. Null attaches no inline policy."
  type        = string
  default     = null
}

variable "managed_policy_arns" {
  description = "AWS managed policies to attach. Prefer inline_policy_json; AWS managed policies are broader."
  type        = list(string)
  default     = []
}
