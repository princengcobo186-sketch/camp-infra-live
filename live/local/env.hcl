# Local development: a Kind cluster on this machine. No AWS account, region or credentials.
# root.hcl selects a local backend and skips the AWS provider for this environment.
locals {
  environment = "local"

  # kubeconfig context Kind creates for kind/cluster.yaml (cluster name "camp").
  kube_context = "kind-camp"
}
