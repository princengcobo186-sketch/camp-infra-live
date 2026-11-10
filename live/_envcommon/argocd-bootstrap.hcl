# Shared definition of the argocd-bootstrap stack. Identical in every environment, local Kind
# included; per-environment differences come from env.hcl. Running the same module on Kind and
# on EKS is what makes the local loop a faithful rehearsal of the cloud one.

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${get_repo_root()}/modules//argocd-bootstrap"
}

# The helm provider talks to whichever cluster the kubeconfig context names. Local only for
# now; the EKS stacks (Phase 3) add cluster endpoint and exec-based auth instead of a context.
generate "helm_provider" {
  path      = "helm_provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOF
    provider "helm" {
      kubernetes = {
        config_path    = "~/.kube/config"
        config_context = "${local.env_vars.locals.kube_context}"
      }
    }
  EOF
}

inputs = {
  # Pinned. Bump deliberately, in a PR, one environment at a time.
  argocd_chart_version      = "10.17.1"
  argocd_apps_chart_version = "2.0.8"

  gitops_repo_url = "https://github.com/princengcobo186-sketch/camp-k8s-gitops.git"
  gitops_revision = try(local.env_vars.locals.gitops_revision, "main")
  auto_prune      = try(local.env_vars.locals.argocd_auto_prune, true)
}
