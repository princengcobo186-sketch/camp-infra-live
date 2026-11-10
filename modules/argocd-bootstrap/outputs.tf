output "namespace" {
  description = "Namespace Argo CD runs in."
  value       = helm_release.argocd.namespace
}

output "root_application" {
  description = "Name of the root Application watching clusters/<environment>."
  value       = local.root_app_name
}
