# Local development loop (Kind, $0)

Runs the same Argo CD bootstrap module as EKS, against a Kind cluster on your machine. No AWS
account, region or credentials are involved.

## Prerequisites

- Docker usable by your user (`docker ps` works without sudo).
- `asdf install` in each repo (pins kind, kubectl, helm, uv, terraform, terragrunt).
- `camp-k8s-gitops` main contains `clusters/local`, and `camp-payment-service` has the
  `chart-v0.1.0` tag. Argo CD pulls both from GitHub, so they must be merged and pushed.

## Bring it up

```bash
# 1. cluster
scripts/kind-up.sh

# 2. image: build and load into the cluster (camp-payment-service)
make -C ../camp-payment-service kind-load

# 3. Argo CD and the root Application
cd live/local/argocd-bootstrap
terragrunt apply

# 4. watch Argo reconcile everything from git
kubectl --context kind-camp -n argocd get applications -w
```

Expect `projects` then `payment-service` to reach `Synced` / `Healthy`.

## Try it

```bash
kubectl --context kind-camp -n payments port-forward svc/payment-service 8080:80 &
curl -s localhost:8080/readyz
curl -s -X POST localhost:8080/payments \
  -H 'Idempotency-Key: demo-key-0001' -H 'Content-Type: application/json' \
  -d '{"amount_minor": 2500, "currency": "ZAR", "reference": "order-1"}'
```

Repeat the POST: the same payment comes back with HTTP 200 (idempotent replay).

## Prove GitOps works

Change `replicaCount` or `env.LOG_LEVEL` in `camp-k8s-gitops/apps/payment-service/`, merge it,
and watch the cluster follow without any `kubectl apply`.

## Tear down

```bash
scripts/kind-up.sh --down
rm live/local/argocd-bootstrap/terraform.tfstate*   # state belongs to the deleted cluster
```

## Troubleshooting

| Symptom | Cause |
|---|---|
| `permission denied ... docker.sock` | user not in the `docker` group |
| `payment-service` is `ImagePullBackOff` / `ErrImageNeverPull` | image not loaded; run `make kind-load` |
| `payment-service` OutOfSync, "unable to resolve chart-v0.1.0" | chart tag not pushed to camp-payment-service |
| Argo cannot find `clusters/local` | the gitops PR is not merged to `main` yet |
