# Shared definition of the argocd-bootstrap stack. Identical in every environment, local Kind
# included; per-environment differences come from env.hcl. Running the same module on Kind and on
# EKS is what makes the local loop a faithful rehearsal of the cloud one.

terraform {
  source = "${get_repo_root()}/modules//argocd-bootstrap"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  is_local = local.env_vars.locals.environment == "local"

  # Kind uses the kubeconfig context Kind created. EKS reads the cluster endpoint and CA from AWS
  # and authenticates with a short-lived token from the caller's credentials, so no kubeconfig
  # file or long-lived cluster secret is needed.
  local_helm_provider = <<-EOT
    provider "helm" {
      kubernetes = {
        config_path    = "~/.kube/config"
        config_context = "${try(local.env_vars.locals.kube_context, "")}"
      }
    }
  EOT

  eks_helm_provider = <<-EOT
    data "aws_eks_cluster" "this" {
      name = "${try(local.env_vars.locals.cluster_name, "")}"
    }

    data "aws_eks_cluster_auth" "this" {
      name = "${try(local.env_vars.locals.cluster_name, "")}"
    }

    provider "helm" {
      kubernetes = {
        host                   = data.aws_eks_cluster.this.endpoint
        cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
        token                  = data.aws_eks_cluster_auth.this.token
      }
    }
  EOT
}

generate "helm_provider" {
  path      = "helm_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = local.is_local ? local.local_helm_provider : local.eks_helm_provider
}

inputs = {
  # Pinned. Bump deliberately, in a PR, one environment at a time.
  argocd_chart_version      = "10.17.1"
  argocd_apps_chart_version = "2.0.8"

  gitops_repo_url = "https://github.com/princengcobo186-sketch/camp-k8s-gitops.git"
  gitops_revision = try(local.env_vars.locals.gitops_revision, "main")
  auto_prune      = try(local.env_vars.locals.argocd_auto_prune, true)
}
