# ADR 0001: EKS Pod Identity instead of IRSA; IAM users instead of GitHub OIDC

- Status: accepted
- Date: 2026-11-10

## Context

The AWS account runs under a managed service control policy that denies `iam:*Provider*`.
Both IRSA (IAM Roles for Service Accounts) and GitHub Actions OIDC federation need an IAM
OpenID Connect provider, so neither can be created. Lifting the restriction means activating
"advanced features" on the AWS organization, which is irreversible.

## Decision

- **Pods** get AWS permissions through **EKS Pod Identity** (`eks-pod-identity-agent` add-on
  plus `aws_eks_pod_identity_association`). It trusts the `pods.eks.amazonaws.com` service
  principal and needs no OIDC provider.
- The EKS module is called with **`enable_irsa = false`**. The community module enables IRSA
  by default, which would try to create an OIDC provider and fail the first apply on the SCP.
- **CI** reaches AWS via an IAM user whose only permission is `sts:AssumeRole` into a scoped
  role, the pattern proven in `multi-env-infra/bootstrap/ci_access.tf`. Access keys are created
  and rotated by `scripts/ci-key.sh`, straight into GitHub secrets, never via Terraform.

## Consequences

- Associations are keyed by **namespace + ServiceAccount name**, so `camp-k8s-gitops` never
  handles role ARNs. Renaming a ServiceAccount in a chart is a breaking change that needs a
  matching change in this repo.
- CI holds long-lived keys. They are contained by GitHub environment secrets restricted to
  `main`/`v*`, and by roles that can only reach their own state prefix.
- If advanced features are ever activated, replace the IAM users with GitHub OIDC
  (`token.actions.githubusercontent.com`) and delete the users and keys.
