# Thin wrapper around terraform-aws-modules/vpc, pinned. The subnet layout is derived from the
# CIDR so every environment has the same shape: /20 private subnets for nodes and pods, /24
# public subnets for load balancers and NAT, all in the upper part of the range.

locals {
  az_count        = length(var.azs)
  private_subnets = [for i in range(local.az_count) : cidrsubnet(var.cidr, 4, i)]
  public_subnets  = [for i in range(local.az_count) : cidrsubnet(var.cidr, 8, 128 + i)]
  nat_count       = var.nat_gateway_mode == "single" ? 1 : local.az_count
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  name = "${var.project}-${var.environment}"
  cidr = var.cidr
  azs  = var.azs

  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway     = true
  single_nat_gateway     = var.nat_gateway_mode == "single"
  one_nat_gateway_per_az = var.nat_gateway_mode == "per_az"

  # Subnet tags the AWS Load Balancer Controller uses to choose subnets for internet-facing and
  # internal load balancers, plus the cluster tag EKS expects.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
