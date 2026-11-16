output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 cluster CA, for the Helm and Kubernetes providers."
  value       = module.eks.cluster_certificate_authority_data
}

output "node_security_group_id" {
  description = "Security group of the managed nodes."
  value       = module.eks.node_security_group_id
}

# Exposed for tests: whether the public endpoint is on is decided here, from the CIDR list.
output "public_api_enabled" {
  description = "True when the public API endpoint is enabled (only ever from the listed CIDRs)."
  value       = local.public_access_enabled
}
