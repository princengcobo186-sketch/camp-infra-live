# Shared definition of the ECR stack. One repository per service, owned by the shared environment
# so every environment promotes the same image digest rather than rebuilding it.

terraform {
  source = "${get_repo_root()}/modules//ecr"
}

inputs = {
  # Must match ecr_repository_name in bootstrap/variables.tf: the push identity's policy is
  # granted on that exact ARN.
  repository_name = "camp/payment-service"
}
