# CAMP Platform Plan: 3-Repo GitOps Payment Platform

Status: accepted (2026-11-10). Phase 0 in progress. Nothing has been applied to AWS.

## 0. Ground truth (verified, not assumed)

| Fact | Source | Consequence |
|---|---|---|
| Target is **Amazon EKS** (the brief said "AKS", which is Azure) | brief | All cloud work is EKS |
| Same AWS account as `multi-env-infra` (new AWS experience, `agent-toolkit` profile), single region **eu-north-1** | `multi-env-infra/live/*/env.hcl`, `~/.aws/config` | Everything stays in eu-north-1. No multi-region work. (An earlier draft said af-south-1; that is the region of other profiles on this machine, not this account.) |
| Managed SCP **denies `iam:*Provider*`** | `multi-env-infra/bootstrap/ci_access.tf` | **No GitHub OIDC** and **no EKS IRSA** (both need an IAM OIDC provider). Use **EKS Pod Identity** for pods and the IAM-user → assume-role pattern for CI |
| Established Terragrunt pattern: `live/root.hcl`, `_envcommon/`, env guard regex, S3 native lockfile, `allowed_account_ids`, `bootstrap/` for state and CI identities, local modules with `tftest` | `multi-env-infra/` | Reuse it. Don't invent a second convention (Core Rule 8) |
| Tools (asdf): terraform 1.16.7, terragrunt 1.1.4, tflint 0.65.0, kubectl 1.37.2, helm 4.3.1, kind 0.33.0, uv 0.13.7; docker 29 | `.tool-versions` | kubectl/helm/kind installed in Phase 0 |
| `terraform-aws-modules/eks` turns on `enable_irsa` by default, which creates an OIDC provider | module default | Must set `enable_irsa = false`, or the first apply fails on the SCP |

## 1. Architecture

```
 camp-payment-service (repo 3)          camp-k8s-gitops (repo 2)              camp-infra-live (repo 1)
 ─────────────────────────────          ────────────────────────              ───────────────────────
 code + tests + Dockerfile + chart      desired cluster state (per env)       VPC, EKS, ECR, IAM, Argo CD install
        │                                     ▲          │                          │
        │ CI: test → build → scan             │          │ Argo CD pulls             │ terragrunt apply
        ▼                                     │          ▼                          ▼
   Amazon ECR (shared, IMMUTABLE) ──digest──► PR bumps    Kind (local) / EKS dev/staging/prod
        ▲                                   image tag      ▲
        └──────────── nodes pull image ─────────────────────┘
```

### Ownership lines (one owner per thing, no dual control)

| Thing | Owner | Never touched by |
|---|---|---|
| VPC, EKS, node groups, ECR, IAM roles, Pod Identity associations, Argo CD **install** + root Application | repo 1 (Terraform) | Argo CD |
| Everything inside the cluster after bootstrap: add-ons, AppProjects, namespaces, the app | repo 2 (Argo CD) | Terraform |
| Application code, image, Helm chart *templates* | repo 3 | repos 1 and 2 |
| Which image version runs in which env, and env-specific values | repo 2 | repo 3 (it can only *propose*, by PR) |

### Contracts between repos (the only coupling allowed)

| From → To | Contract | Mechanism |
|---|---|---|
| 1 → 2 | Cluster `camp-<env>` exists, Argo CD runs, root app watches `camp-k8s-gitops/clusters/<env>` | `argocd-bootstrap` stack |
| 1 → 2 | IAM for pods is bound by **namespace + ServiceAccount name** (Pod Identity), so repo 2 never handles role ARNs | `aws_eks_pod_identity_association` in repo 1 |
| 3 → ECR | Image `camp/payment-service:<git-sha>`, immutable tag, scanned | CI push role (push to this one repo only) |
| 3 → 2 | PR changing `apps/payment-service/envs/dev/values.yaml` `image.tag` | GitHub App (preferred) or fine-grained PAT scoped to repo 2 only |
| 2 → 3 | Argo pulls chart from repo 3 at git tag `chart-vX.Y.Z` and values from repo 2 | Argo CD multi-source Application |

Why the chart is pulled from git and not from ECR as an OCI artifact: ECR auth tokens expire every 12h and Argo CD has no native refresh. You'd need an extra credential-rotation CronJob. That can come later. Git-tag sourcing works with no extra moving parts.

## 2. Environments and promotion path

```
local (Kind, $0) ──► dev (EKS) ──► staging (EKS) ──► prod (EKS)
  make dev            auto on merge     PR promotion      PR promotion + GitHub environment gate
```

| Hop | Trigger | Validates | Approves | Rollback |
|---|---|---|---|---|
| local | `make dev` | unit/integration tests, chart renders, pod Ready | you | `kind delete cluster` |
| → dev | merge to `main` in repo 3 → CI opens and auto-merges a tag-bump PR in repo 2 | CI gates + Argo sync health + smoke test | CI | revert the gitops commit |
| → staging | PR in repo 2 copying the **same tag** from dev | dev healthy, smoke tests | you | revert the gitops commit |
| → prod | PR in repo 2 copying the **same tag** from staging | staging soak, alerts quiet | you (protected branch / CODEOWNERS) | revert the gitops commit (Argo re-syncs the previous digest) |

Rule: images are built **once** in repo 3 and promoted by tag. Nothing is ever rebuilt per environment.

**Kind vs ECR:** in local dev, images are built and loaded with `kind load docker-image`. That's zero cloud cost and needs no 12h ECR token handling. ECR is the single registry for every image that gets *promoted* (dev and above). Optional: a `make dev-ecr` target pulls a released image from ECR into Kind to reproduce an env bug.

**Cost reality (eu-north-1):** each EKS cluster costs about $73/mo for the control plane, plus nodes and a NAT gateway. Defaults: one NAT gateway in non-prod, SPOT nodes in dev, and a `destroy` workflow so clusters are ephemeral (stand up, demo, tear down). Staging stays in code but is only applied when you're exercising the full promotion path.

**Blast radius:** this is one AWS account, so isolation comes from per-env state prefixes, per-env CI roles that can only touch their own state prefix, `allowed_account_ids`, and the env guard regex. Enterprise would use an account per env. The new AWS experience allows multiple "projects" (one account each), so that's a documented upgrade path, not day-1 scope.

## 3. Repo 1: `camp-infra-live` (restructure)

Changes from the current skeleton: `environments/` → `live/`, `envcommon/` → `_envcommon/`, root `terragrunt.hcl` → `live/root.hcl` (Terragrunt 1.x convention, same as the sibling repo). Add `bootstrap/`, `modules/`, a `shared` env for ECR, and a `local` env for Kind.

```
camp-infra-live/
├── .tool-versions              # terraform, terragrunt, tflint, kubectl, helm, kind, kubeconform
├── .pre-commit-config.yaml     # fmt, tflint, detect-private-key, terragrunt hclfmt
├── .tflint.hcl
├── .gitignore                  # .terraform, .terragrunt-cache, *.tfplan, kubeconfig*
├── README.md
├── docs/
│   ├── platform-plan.md        # this file
│   ├── architecture.md
│   ├── operations.md           # bootstrap order, key rotation, destroy, break-glass
│   └── adr/                    # 0001-pod-identity-not-irsa.md, 0002-chart-from-git.md, ...
├── bootstrap/                  # applied once with local state, then migrated to S3
│   ├── state.tf                # S3 state bucket (versioned, encrypted, TLS-only, public access blocked)
│   ├── ci_access.tf            # per-env plan/apply users→roles + ecr-push user→role for repo 3
│   └── ...
├── modules/                    # thin wrappers; community modules pinned to exact versions
│   ├── vpc/                    # wraps terraform-aws-modules/vpc
│   ├── eks/                    # wraps terraform-aws-modules/eks: enable_irsa=false, API auth mode
│   │                           #   (access entries), pod-identity-agent add-on, managed node group
│   ├── ecr/                    # IMMUTABLE tags, scan on push, KMS, lifecycle policy, repo policy
│   ├── pod-identity/           # role + association per (namespace, serviceaccount)
│   └── argocd-bootstrap/       # helm_release argo-cd (pinned) + argocd-apps root Application
│       └── tests/*.tftest.hcl  # each module has tests, as in the sibling repo
├── scripts/
│   ├── ci-key.sh               # creates and rotates CI access keys straight into GH secrets (never in state)
│   └── kind-up.sh              # idempotent: create cluster only if absent
├── kind/
│   └── cluster.yaml            # 1 control-plane + 2 workers, port mappings 80/443, pinned node image
├── live/
│   ├── root.hcl                # backend, provider, default_tags, env guard, allowed_account_ids
│   ├── _envcommon/
│   │   ├── vpc.hcl  eks.hcl  ecr.hcl  pod-identity.hcl  argocd-bootstrap.hcl
│   ├── local/
│   │   ├── env.hcl             # environment="local", backend=local, kube_context="kind-camp"
│   │   └── argocd-bootstrap/   # SAME module as EKS, which is what makes the switch seamless
│   ├── shared/
│   │   ├── env.hcl
│   │   └── ecr/                # account-level registry, used by all envs
│   ├── dev/
│   │   ├── env.hcl
│   │   ├── vpc/  eks/  pod-identity/  argocd-bootstrap/
│   ├── staging/  (same shape)
│   └── prod/     (same shape)
└── .github/workflows/
    ├── ci.yml                  # fmt, tflint, validate, tftest, checkov/trivy config scan
    ├── plan.yml                # PR: read-only plan for changed stacks (plan role)
    ├── deploy.yml              # main → dev; tags v* → staging/prod via GitHub environments
    └── destroy.yml             # manual, env-scoped, typed confirmation
```

Notes:
- `root.hcl` switches backend on environment: `local` uses a local backend and no AWS provider, so Kind costs $0 and needs no credentials. Everything else uses S3. The env guard regex stays.
- `argocd-bootstrap` depends on `eks` (via `dependency` with `mock_outputs` for plan). Keeping it a **separate stack** from `eks` avoids the classic "helm provider configured from a cluster that doesn't exist yet" failure. Your skeleton already does this, which is good.
- Argo CD install inputs per env: chart version, `clusters/<env>` path, and repo URL. The root Application uses `automated: {prune: true, selfHeal: true}` in local/dev and `automated` without prune in prod.
- Repo access for Argo: public repos need no credentials. If repo 2 is private, use a read-only deploy key stored in Secrets Manager. Never put it in tfvars or state (Core Rule 7).

## 4. Repo 2: `camp-k8s-gitops`

App-of-Apps: one root Application per cluster → `clusters/<env>/` → child Applications for platform add-ons and workloads.

```
camp-k8s-gitops/
├── README.md
├── docs/  (promotion.md, adding-an-app.md, rollback.md)
├── clusters/                       # the root app points here; one dir per env
│   ├── local/
│   │   ├── kustomization.yaml      # lists the Applications enabled for this cluster
│   │   ├── platform.yaml           # Applications for add-ons (wave -10..0)
│   │   └── apps.yaml               # Applications for workloads (wave 10+)
│   ├── dev/  staging/  prod/
├── projects/                       # AppProjects = RBAC + blast radius in Argo
│   ├── platform.yaml               # may create cluster-scoped resources
│   └── payments.yaml               # namespace `payments` only, sources limited to repos 2+3, no cluster resources
├── platform/                       # cluster add-ons, each: pinned chart version + values per env
│   ├── argocd/                     # Argo CD manages its own config (not its install; repo 1 owns that)
│   ├── external-secrets/           # ESO → AWS Secrets Manager via Pod Identity (fake provider in local)
│   ├── aws-load-balancer-controller/   # EKS only
│   ├── gateway/                    # Gateway API implementation (e.g. Envoy Gateway). Avoid ingress-nginx, retired upstream
│   ├── metrics-server/
│   ├── kube-prometheus-stack/      # metrics + alerting (Observability ships with the feature)
│   ├── kyverno/                    # policy: non-root, no :latest, ECR-only images, resource limits
│   └── <addon>/values-{common,local,dev,staging,prod}.yaml
├── apps/
│   └── payment-service/
│       ├── application.yaml        # template for the multi-source app (chart from repo 3 + values from here)
│       ├── values-common.yaml
│       └── envs/
│           ├── local/values.yaml   # image.repository=camp/payment-service (kind-loaded), replicas=1
│           ├── dev/values.yaml     # image.tag=<sha> (bumped by CI)
│           ├── staging/values.yaml # image.tag promoted by PR
│           └── prod/values.yaml    # image.tag promoted by PR; HPA, PDB, more replicas
└── .github/
    ├── CODEOWNERS                  # clusters/prod/** and apps/*/envs/prod/** require your review
    └── workflows/
        └── validate.yml            # helm template every app×env → kubeconform → kyverno CLI test → diff comment
```

Sync waves: CRDs/operators (−10) → policies (−5) → secrets/gateway (0) → apps (10). This keeps the app from deploying before its ExternalSecret CRD exists.

## 5. Repo 3: `camp-payment-service`

**Language: Python (FastAPI) recommended over Node.js** for a payments service. `decimal.Decimal` is in the stdlib (Node has no native decimal type), Pydantic validates money and currency at the edge, and `uv` gives a reproducible lockfile. Amounts are stored as integer minor units regardless.

```
camp-payment-service/
├── pyproject.toml  uv.lock  .python-version
├── src/payment_service/
│   ├── main.py                 # app factory
│   ├── api/                    # routes: POST /payments (Idempotency-Key required), GET /payments/{id}
│   ├── domain/                 # Payment model, state machine (PENDING→AUTHORIZED→CAPTURED|FAILED)
│   ├── adapters/               # repository (Postgres; in-memory for tests), provider (fake gateway)
│   ├── config.py               # 12-factor env config; fails closed if required config is missing
│   └── observability.py        # JSON logs with request_id, /metrics (Prometheus), OTel hooks
├── tests/
│   ├── unit/  integration/  contract/   # incl. failure paths: duplicate idempotency key, invalid currency
├── Dockerfile                  # multi-stage, base pinned by digest, non-root UID, read-only FS, no shell in final
├── .dockerignore
├── chart/payment-service/      # app team owns the templates; env values live in repo 2
│   ├── Chart.yaml  values.yaml  values.schema.json
│   ├── templates/  deployment, service, serviceaccount, hpa, pdb, networkpolicy,
│   │               servicemonitor, externalsecret, httproute
│   └── tests/      # helm-unittest
├── Makefile                    # make test | make build | make dev (kind-up → build → kind load → helm upgrade)
├── docs/  (api.md, runbook.md: alerts → what to check)
└── .github/workflows/
    ├── ci.yml                  # PR: ruff, mypy, pytest+coverage, helm lint/unittest, hadolint, docker build, trivy
    └── release.yml             # main: build once → trivy (fail on HIGH/CRITICAL) → SBOM → push ECR :<sha>
                                #   → open PR in repo 2 bumping dev tag; chart change → tag chart-vX.Y.Z
```

Payments-specific guardrails: no real card data (PCI scope), a fake provider adapter only, idempotency keys enforced at the API, and no secrets in env defaults or the chart. Secrets come from ESO.

## 6. Security baseline (all repos)

- All three repos **public** on your personal GitHub (good for a portfolio). That also makes branch protection, environments with required reviewers, CodeQL, and Dependabot free. These gates silently don't exist on private repos on a free plan. Account ID and alert emails go in GitHub secrets so they're masked in logs.
- Pin actions by SHA, use `permissions: contents: read` by default, `persist-credentials: false`, and Dependabot/Renovate for actions, charts, base images, and providers.
- CI AWS access follows the sibling pattern (IAM user that can only `sts:AssumeRole` → scoped role). Keys are created by script, never by Terraform. Apply keys go in GitHub **environment** secrets restricted to `main`/`v*`. Re-evaluate OIDC if advanced features are ever enabled.
- Cluster access uses EKS access entries (no `aws-auth` ConfigMap). Private endpoint plus a public endpoint restricted by CIDR in non-prod.
- Never upload plan files as CI artifacts.

## 7. Delivery phases (each ends with a verifiable gate)

| Phase | Scope | Exit gate |
|---|---|---|
| **0. Foundations** | Restructure repo 1, `.tool-versions` (+kind/kubectl/helm), pre-commit, create the three GitHub repos, branch protection, CODEOWNERS | `pre-commit run -a` clean; empty CI green in all 3 repos |
| **1. Local loop ($0)** | Repo 3 minimal service + Dockerfile + chart; repo 1 `kind/` + `live/local/argocd-bootstrap`; repo 2 `clusters/local` with payment-service | `make dev` → Argo shows Synced/Healthy → `curl` POST /payments works → editing a value in repo 2 auto-syncs |
| **2. AWS bootstrap** | `bootstrap/` (state bucket, CI identities), `live/shared/ecr`; repo 3 `release.yml` pushes to ECR | Image in ECR with immutable tag and scan results; re-push of the same tag is rejected |
| **3. dev on EKS** | `live/dev/{vpc,eks,pod-identity,argocd-bootstrap}`; platform add-ons; app from ECR | Read the plan diff fully → apply → Argo Healthy → smoke test via ALB → Grafana shows request metrics → `destroy.yml` tears it down cleanly |
| **4. Promotion** | Automated dev tag-bump PR; staging/prod stacks; prod gates | The same digest is observed running in dev → staging → prod; a rollback by git revert is demonstrated |
| **5. Hardening** | Kyverno policies enforced, NetworkPolicies, cosign sign/verify, alert rules + receiver, runbooks, cost budget alarm | Policy blocks a `:latest` / non-ECR image; firing a test alert reaches you |

## 8. Decisions (confirmed 2026-11-10)

1. Repo 3 language: **Python** (FastAPI, uv).
2. Repo visibility: **public** on `github.com/princengcobo186-sketch`.
3. Staging: **in code, applied only on demand**.
4. AWS accounts: **one account now** (the one `multi-env-infra` uses); account-per-env is a documented upgrade path.
5. Cross-repo PR identity (repo 3 → repo 2): **GitHub App**, created in Phase 4.

## 9. Reuse from `multi-env-infra`

`multi-env-infra` stays an independent project. Nothing here references it at runtime (no git
module sources, no shared state, no shared CI identities). Proven patterns are **copied once
and adapted**, so the two can evolve separately. See `adr/0002-reuse-from-multi-env-infra.md`.
