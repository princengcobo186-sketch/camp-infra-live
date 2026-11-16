include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/pod-identity.hcl"
  expose = true
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name = "camp-dev"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# AWS Load Balancer Controller (chart 3.6.3, app v3.6.3). The policy is the upstream one for that
# tag, vendored in modules/pod-identity/policies so a version bump is a reviewed diff.
inputs = {
  cluster_name       = dependency.eks.outputs.cluster_name
  name               = "aws-load-balancer-controller"
  namespace          = "kube-system"
  service_account    = "aws-load-balancer-controller"
  inline_policy_json = file("${get_repo_root()}/modules/pod-identity/policies/aws-load-balancer-controller.json")
}
