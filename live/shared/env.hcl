# Account-level resources used by every environment (the ECR registry). Kept out of dev/
# staging/prod so the same image digest is promoted between them, never copied or rebuilt.
locals {
  environment = "shared"
  region      = "eu-north-1"

  # Required, with no default: the account is never discovered implicitly. It feeds the state
  # bucket name and the provider's allowed_account_ids, so credentials for the wrong account
  # fail closed at plan time instead of deploying into it.
  account_id = get_env("TG_ACCOUNT_ID")
}
