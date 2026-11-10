variable "project" {
  description = "Project name."
  type        = string
}

variable "environment" {
  description = "Environment name (local, dev, staging, prod). Selects the clusters/<env> path in the gitops repo."
  type        = string
}

variable "namespace" {
  description = "Namespace Argo CD is installed into."
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Exact argo-cd Helm chart version. Pinned: an unpinned chart changes cluster behaviour on any apply."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.argocd_chart_version))
    error_message = "argocd_chart_version must be an exact version such as 10.17.1."
  }
}

variable "argocd_apps_chart_version" {
  description = "Exact argocd-apps Helm chart version, used to create the root Application."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.argocd_apps_chart_version))
    error_message = "argocd_apps_chart_version must be an exact version such as 2.0.8."
  }
}

variable "gitops_repo_url" {
  description = "HTTPS URL of the gitops repository Argo CD watches. Public, so no credentials are needed."
  type        = string

  validation {
    condition     = startswith(var.gitops_repo_url, "https://")
    error_message = "gitops_repo_url must be an https:// URL. Never embed credentials in it."
  }
}

variable "gitops_revision" {
  description = "Branch or tag of the gitops repository the root Application tracks."
  type        = string
  default     = "main"
}

variable "auto_prune" {
  description = "Whether Argo CD deletes resources removed from git. Off for prod: a bad commit must not delete live workloads."
  type        = bool
  default     = true
}

variable "extra_argocd_values" {
  description = "Extra values (as an object) merged over the module defaults, for per-environment differences."
  type        = any
  default     = {}
}
