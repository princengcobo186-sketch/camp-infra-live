# Environment identity and the knobs that legitimately differ between environments.
# Anything not listed here is identical everywhere by design (see _envcommon/).
# Production-shaped. Still destroyed when not demonstrating, to control cost.
locals {
  environment = "prod"
  region      = "eu-north-1"
  account_id  = get_env("TG_ACCOUNT_ID")

  # Non-overlapping CIDRs keep peering/VPN options open later.
  vpc_cidr = "10.40.0.0/16"

  # "single" = one shared NAT (cheap, one AZ is a failure domain); "per_az" = one per AZ.
  nat_gateway_mode = "per_az"

  # EKS managed node group capacity type.
  node_capacity_type = "ON_DEMAND"
}
