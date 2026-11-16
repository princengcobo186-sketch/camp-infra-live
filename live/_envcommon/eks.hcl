# Shared definition of the EKS cluster stack. Consumes the VPC from the sibling vpc stack.

terraform {
  source = "${get_repo_root()}/modules//eks"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  cluster_name                 = local.env_vars.locals.cluster_name
  kubernetes_version           = local.env_vars.locals.kubernetes_version
  endpoint_public_access_cidrs = local.env_vars.locals.endpoint_public_access_cidrs
  node_capacity_type           = local.env_vars.locals.node_capacity_type
}
