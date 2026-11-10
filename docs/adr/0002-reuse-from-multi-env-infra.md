# ADR 0002: Copy-and-adapt reuse from multi-env-infra, no runtime dependency

- Status: accepted
- Date: 2026-11-10

## Context

`multi-env-infra` is a separate project in the same AWS account. It already has a hardened,
tested Terragrunt layout. CAMP must not be coupled to it: either project must be changeable or
deletable without breaking the other.

Options considered:

1. **Reference its modules by git source** (`git::…/multi-env-infra//modules/vpc?ref=vX`).
   Real reuse, but it creates a cross-project dependency and makes CAMP's VPC depend on another
   project's release cadence.
2. **Extract a shared module repository** consumed by both. The enterprise answer once there
   are three or more consumers. Over-engineered for two independent portfolio projects.
3. **Copy once, adapt, own it.** No coupling. Divergence is accepted and intended.

## Decision

Option 3. Revisit option 2 if a third consumer appears.

| From multi-env-infra | Reuse | Adaptation for CAMP |
|---|---|---|
| `live/root.hcl` (env guard, `allowed_account_ids`, S3 native lock, default tags) | yes | `local` environment: local backend, no AWS provider |
| `live/_envcommon/` + per-env `env.hcl` layout | yes | `shared` env for ECR; EKS knobs |
| `bootstrap/state.tf` (versioned, TLS-only, `prevent_destroy` state bucket) | yes, near verbatim | project = `camp` |
| `bootstrap/ci_access.tf` (user→role, per-env state-prefix isolation with explicit deny) | yes | adds EKS/ECR apply permissions and an ECR-push identity for `camp-payment-service` |
| `scripts/ci-key.sh` (key straight to `gh secret set`, safe rotation) | yes | project and environment names as parameters |
| `.github/workflows/*` (SHA-pinned, asdf-driven, plan on PR, env-gated apply, destroy) | yes | adds kubeconform/helm steps where relevant |
| `modules/vpc` (+ tftests) | yes, in Phase 3 | adds EKS subnet tags (`kubernetes.io/role/elb`, `internal-elb`) |
| `modules/notifications` (SNS) | likely, Phase 5 | alert and budget notifications |
| `modules/rds` | maybe | only if the payment service moves from in-cluster Postgres to RDS |
| `modules/alb` | no | ingress is owned by the AWS Load Balancer Controller inside the cluster |

## Consequences

- A security fix made in one repo must be ported manually to the other. The table above is the
  checklist for doing that.
- Resource names, state bucket, CI users and roles are all prefixed `camp-`, so the two
  projects cannot collide in the shared account.
