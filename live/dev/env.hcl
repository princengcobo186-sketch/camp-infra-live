# Environment identity and the knobs that legitimately differ between environments.
# Anything not listed here is identical everywhere by design (see _envcommon/).
# Ephemeral: applied for work sessions, destroyed after.
locals {
  environment = "dev"
  region      = "eu-north-1"
  account_id  = get_env("TG_ACCOUNT_ID")

  # Non-overlapping CIDRs keep peering/VPN options open later.
  vpc_cidr = "10.20.0.0/16"

  # "single" = one shared NAT (cheap, one AZ is a failure domain); "per_az" = one per AZ.
  nat_gateway_mode = "single"

  # EKS managed node group capacity type.
  node_capacity_type = "SPOT"
}
