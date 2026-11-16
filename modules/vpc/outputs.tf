output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets: EKS nodes and the control-plane ENIs."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnets: internet-facing load balancers and NAT gateways."
  value       = module.vpc.public_subnets
}

# Exposed for tests: the derived layout is what the rest of the platform assumes.
output "private_subnet_cidrs" {
  description = "CIDRs of the private subnets, for layout checks."
  value       = local.private_subnets
}

output "public_subnet_cidrs" {
  description = "CIDRs of the public subnets, for layout checks."
  value       = local.public_subnets
}

output "nat_gateway_count" {
  description = "Number of NAT gateways this layout creates: 1 in single mode, one per AZ in per_az mode."
  value       = local.nat_count
}
