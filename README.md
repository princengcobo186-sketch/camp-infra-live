# camp-infra-live

Infrastructure for **CAMP**, a GitOps platform running a containerized payment processing
microservice. This repository provisions the cloud foundations (VPC, EKS, ECR, IAM) with
Terraform and Terragrunt, and bootstraps Argo CD into each cluster. From that point Argo CD
owns everything inside the cluster.

It is one of three repositories:

| Repository | Owns |
|---|---|
| **camp-infra-live** (this) | AWS foundations, the Argo CD install and its root Application |
| [camp-k8s-gitops](https://github.com/princengcobo186-sketch/camp-k8s-gitops) | Desired cluster state per environment (App-of-Apps) |
| [camp-payment-service](https://github.com/princengcobo186-sketch/camp-payment-service) | Application code, tests, container image, Helm chart |

## Environments

| Environment | Where | State | Cost |
|---|---|---|---|
| `local` | Kind on your machine | local file | $0 |
| `shared` | AWS eu-north-1 (ECR registry used by every env) | S3 | cents |
| `dev` | AWS eu-north-1, EKS | S3 | ephemeral: destroyed after use |
| `staging` | AWS eu-north-1, EKS | S3 | applied only to exercise promotion |
| `prod` | AWS eu-north-1, EKS | S3 | production-shaped, destroyed when idle |

## Layout

```
live/
  root.hcl           backend + provider generation, env guard (every stack includes it)
  _envcommon/        one shared definition per stack type
  <env>/env.hcl      the only values that differ between environments
  <env>/<stack>/     a deployable unit with its own state
modules/             versioned Terraform modules with mocked tests
bootstrap/           state bucket and CI identities (applied once, by an admin)
docs/                plan, ADRs, operations
```

## Getting started

```bash
asdf install          # terraform, terragrunt, tflint, kubectl, helm, kind
pre-commit install
```

AWS environments require `TG_ACCOUNT_ID` to be set explicitly. It is never discovered from
your credentials, so credentials for the wrong account fail at plan time.

## Status

Phase 1 (local loop) in progress: see [docs/local-development.md](docs/local-development.md). See [docs/platform-plan.md](docs/platform-plan.md) for the full plan
and [docs/adr/](docs/adr/) for the decisions behind it.
