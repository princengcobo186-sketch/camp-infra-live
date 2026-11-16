# Shared definition of the VPC stack. Identical in every environment; differences come from env.hcl.

terraform {
  source = "${get_repo_root()}/modules//vpc"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  cluster_name     = local.env_vars.locals.cluster_name
  cidr             = local.env_vars.locals.vpc_cidr
  azs              = local.env_vars.locals.azs
  nat_gateway_mode = local.env_vars.locals.nat_gateway_mode
}
