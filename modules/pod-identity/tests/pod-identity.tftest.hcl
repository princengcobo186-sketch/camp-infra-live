# Real provider with dummy credentials and every AWS call skipped: a plan of these resources
# needs no AWS access, and the policy documents must be real JSON for the trust assertion.
provider "aws" {
  region                      = "eu-north-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = "true"
  skip_region_validation      = true
}

variables {
  project         = "camp"
  environment     = "dev"
  cluster_name    = "camp-dev"
  name            = "aws-load-balancer-controller"
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
}

run "trust_is_pod_identity_only" {
  command = plan

  assert {
    condition     = can(regex("pods.eks.amazonaws.com", data.aws_iam_policy_document.trust.json))
    error_message = "the trust must name the Pod Identity service principal."
  }
}

run "no_inline_policy_when_none_given" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.inline) == 0
    error_message = "without inline_policy_json, no inline policy must be created."
  }
}

run "inline_policy_when_given" {
  command = plan

  variables {
    inline_policy_json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }

  assert {
    condition     = length(aws_iam_role_policy.inline) == 1
    error_message = "a supplied inline policy must be attached to the role."
  }
}

run "rejects_empty_service_account" {
  command = plan

  variables {
    service_account = ""
  }

  expect_failures = [var.service_account]
}
