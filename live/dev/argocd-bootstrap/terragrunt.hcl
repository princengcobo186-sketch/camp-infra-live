include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/argocd-bootstrap.hcl"
  expose = true
}

# Ordering only: Argo CD is installed into the cluster after the cluster exists.
dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name = "camp-dev"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}
