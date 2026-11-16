# Shared definition of a Pod Identity role. Each stack that needs one sets its namespace,
# ServiceAccount and policy. The role is bound to exactly that ServiceAccount.

terraform {
  source = "${get_repo_root()}/modules//pod-identity"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  cluster_name = local.env_vars.locals.cluster_name
}
