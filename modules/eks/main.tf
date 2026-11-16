# Thin wrapper around terraform-aws-modules/eks, pinned. Decisions that differ from the module
# defaults, and why:
#
#   enable_irsa = false
#     The module creates an IAM OIDC provider by default. The account's managed SCP denies
#     iam:*Provider*, so that would fail the first apply. Pods get AWS access via EKS Pod Identity
#     instead (see modules/pod-identity and docs/adr/0001-pod-identity-not-irsa.md).
#
#   authentication_mode = "API"
#     Access entries, not the aws-auth ConfigMap. Access is an AWS API object that Terraform owns.
#
#   Pod Identity agent and VPC CNI are installed before nodes, so pods scheduled on the first
#   nodes get networking and credentials on their first boot.

locals {
  public_access_enabled = length(var.endpoint_public_access_cidrs) > 0
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  tags = {
    Project     = var.project
    Environment = var.environment
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  enable_irsa = false

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  # Private endpoint always. Public only from the listed CIDRs, for the operator's machine.
  endpoint_private_access      = true
  endpoint_public_access       = local.public_access_enabled
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  addons = {
    eks-pod-identity-agent = {
      most_recent    = true
      before_compute = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    kube-proxy = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
    }
  }
}
