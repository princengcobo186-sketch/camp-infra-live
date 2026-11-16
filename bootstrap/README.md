# bootstrap

One-time layer that creates what everything else depends on. It is applied with admin
credentials. Its first apply used **local state**, because it creates the bucket that holds all
other state. That state was then migrated into the bucket (see below).

## What it creates

| Resource | Purpose |
|---|---|
| S3 state bucket `camp-tfstate-<account>-eu-north-1` | Versioned, SSE-S3 encrypted, public access blocked, TLS-only, `prevent_destroy` |
| `camp-<env>-plan-ci` / `camp-<env>-apply-ci` IAM users | One each per environment. Their only permission is `sts:AssumeRole` into their own role. No access keys are created here. |
| `camp-<env>-plan` / `camp-<env>-apply` roles | Assumable only by that environment's CI user. Scoped to the ECR repository and the environment's state prefix. |
| `camp-ecr-push-ci` user and `camp-ecr-push` role | The release pipeline's push identity. It can push to `camp/payment-service` and nothing else. |

Environments are set by `var.environments`. Phase 2 creates only `shared`. `staging`, `dev` and
`prod` are added when they are first applied.

No GitHub OIDC provider: the account's managed service control policy denies `iam:*Provider*`.
See `docs/adr/0001-pod-identity-not-irsa.md`.

## Isolation model (single account)

Each CI role can read and write only `s3://<bucket>/<env>/*`. Reads of every other prefix,
including `bootstrap/`, are explicitly denied. Other prefixes' key names remain listable,
because Terraform's HeadBucket needs `s3:ListBucket`, but their contents are not readable.

This separates state, not AWS resources. The remaining gap is account-wide reads on resource
APIs, which are scoped here to ECR and remain the reason to move to one account per environment
later.

## Run it

Set the account explicitly. It is never discovered from credentials:

```sh
export AWS_PROFILE=automationadmin AWS_REGION=eu-north-1 TG_ACCOUNT_ID=<account-id>
aws sts get-caller-identity          # confirm the account before anything else

cd bootstrap
terraform init -backend-config="bucket=camp-tfstate-${TG_ACCOUNT_ID}-eu-north-1"
terraform plan -out=/tmp/camp-bootstrap.tfplan   # read every line
terraform apply /tmp/camp-bootstrap.tfplan
rm -f /tmp/camp-bootstrap.tfplan                 # plans embed values; never commit or upload them
```

The variable `account_id` is taken from `TF_VAR_account_id`, set to the same value as
`TG_ACCOUNT_ID`. The provider and a postcondition both refuse any other account.

The bucket name contains the account ID, and this repository is public, so the bucket name is
passed at init time rather than committed.

## Create CI access keys (outside Terraform)

Terraform would keep an access key's secret in state in plain text, so keys are created by
`scripts/ci-key.sh`. It pipes them straight into GitHub secrets and never prints them. It is
also the rotation tool: the new key is stored before the old one is deleted.

```sh
./scripts/ci-key.sh princengcobo186-sketch/camp-payment-service ecr-push
```

## Where this layer's state lives

After the first apply the state was migrated into the bucket it created. It is versioned and
no longer a single file on one machine. `versions.tf` declares the backend with no bucket name,
and the bucket is supplied at init time.
