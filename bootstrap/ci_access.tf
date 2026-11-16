# CI identities. Two layers, same pattern as multi-env-infra:
#
#   IAM user - holds a long-lived access key kept in GitHub secrets, and has exactly one
#              permission: sts:AssumeRole into its own role.
#   IAM role - holds the real permissions and trusts only its own user.
#
# WHY NOT GITHUB OIDC: the account's managed service control policy denies iam:*Provider*, so
# the GitHub OIDC provider cannot be created. See docs/adr/0001-pod-identity-not-irsa.md.
#
# Access keys are NOT created here: Terraform would store the secret in state in plain text.
# scripts/ci-key.sh creates and rotates them and writes them straight into GitHub secrets.
#
# Least privilege: no AWS managed ReadOnlyAccess policy. It is account-wide and would let CI read
# every resource in the account. Each role gets only the actions the ECR stack needs, and those
# are granted on the repository ARN. Start with nothing and widen only when a plan or apply
# fails on a specific action.

locals {
  account_arn_prefix = "arn:aws:ecr:${var.region}:${var.account_id}"
  ecr_repo_arn       = "${local.account_arn_prefix}:repository/${var.ecr_repository_name}"
}

# --- Per-environment plan and apply identities -----------------------------------------------

resource "aws_iam_user" "plan" {
  for_each = var.environments

  name = "${var.project}-${each.key}-plan-ci"
}

resource "aws_iam_user" "apply" {
  for_each = var.environments

  name = "${var.project}-${each.key}-apply-ci"
}

data "aws_iam_policy_document" "trust_plan" {
  for_each = var.environments

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.plan[each.key].arn]
    }
  }
}

data "aws_iam_policy_document" "trust_apply" {
  for_each = var.environments

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.apply[each.key].arn]
    }
  }
}

resource "aws_iam_role" "plan" {
  for_each = var.environments

  name                 = "${var.project}-${each.key}-plan"
  assume_role_policy   = data.aws_iam_policy_document.trust_plan[each.key].json
  description          = "CI plan role for ${each.key}: read-only on the ECR repository plus ${each.key} state. Assumable only by its CI user."
  max_session_duration = 3600
}

resource "aws_iam_role" "apply" {
  for_each = var.environments

  name                 = "${var.project}-${each.key}-apply"
  assume_role_policy   = data.aws_iam_policy_document.trust_apply[each.key].json
  description          = "CI apply role for ${each.key}. Assumable only by its CI user."
  max_session_duration = 3600
}

# The user's only permission: assume its own role. The role's trust policy is the second half.
data "aws_iam_policy_document" "assume_plan" {
  for_each = var.environments

  statement {
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.plan[each.key].arn]
  }
}

data "aws_iam_policy_document" "assume_apply" {
  for_each = var.environments

  statement {
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.apply[each.key].arn]
  }
}

resource "aws_iam_user_policy" "plan_assume" {
  for_each = var.environments

  name   = "assume-${var.project}-${each.key}-plan"
  user   = aws_iam_user.plan[each.key].name
  policy = data.aws_iam_policy_document.assume_plan[each.key].json
}

resource "aws_iam_user_policy" "apply_assume" {
  for_each = var.environments

  name   = "assume-${var.project}-${each.key}-apply"
  user   = aws_iam_user.apply[each.key].name
  policy = data.aws_iam_policy_document.assume_apply[each.key].json
}

# --- State access: the isolation boundary between environments --------------------------------
# A role can list and touch only keys under its own "<env>/" prefix. Put and Delete are needed by
# plan roles too, because S3 native locking writes and removes a .tflock object.
#
# The explicit Deny is the part that isolates reads: it blocks reading other environments' state
# and the bootstrap/ state, which an Allow elsewhere could otherwise grant. Listing other key
# names stays allowed because Terraform's HeadBucket needs s3:ListBucket without a prefix.

data "aws_iam_policy_document" "state_access" {
  for_each = var.environments

  statement {
    sid       = "ListOwnPrefix"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = [each.key, "${each.key}/*"]
    }
  }

  statement {
    sid       = "ReadWriteOwnStateAndLock"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/${each.key}/*"]
  }

  statement {
    sid     = "DenyReadingOtherStatePrefixes"
    effect  = "Deny"
    actions = ["s3:GetObject*"]
    resources = concat(
      ["${aws_s3_bucket.state.arn}/bootstrap/*"],
      [for other in setsubtract(var.environments, [each.key]) : "${aws_s3_bucket.state.arn}/${other}/*"],
    )
  }
}

resource "aws_iam_policy" "state_access" {
  for_each = var.environments

  name   = "${var.project}-${each.key}-state-access"
  policy = data.aws_iam_policy_document.state_access[each.key].json
}

resource "aws_iam_role_policy_attachment" "plan_state" {
  for_each = var.environments

  role       = aws_iam_role.plan[each.key].name
  policy_arn = aws_iam_policy.state_access[each.key].arn
}

resource "aws_iam_role_policy_attachment" "apply_state" {
  for_each = var.environments

  role       = aws_iam_role.apply[each.key].name
  policy_arn = aws_iam_policy.state_access[each.key].arn
}

# --- Repository permissions -------------------------------------------------------------------

# Plan: read the repository and its settings, nothing that changes it.
data "aws_iam_policy_document" "plan_ecr" {
  statement {
    sid       = "ReadRepository"
    actions   = ["ecr:Describe*", "ecr:Get*", "ecr:List*"]
    resources = [local.ecr_repo_arn]
  }
}

# Apply: manage the repository and its settings. Scoped to the one repository name; the
# repository is created by this stack, so the ARN is fixed in advance.
data "aws_iam_policy_document" "apply_ecr" {
  statement {
    sid       = "ManageRepository"
    actions   = ["ecr:*"]
    resources = [local.ecr_repo_arn]
  }
}

resource "aws_iam_policy" "plan_ecr" {
  for_each = var.environments

  name   = "${var.project}-${each.key}-plan-ecr"
  policy = data.aws_iam_policy_document.plan_ecr.json
}

resource "aws_iam_policy" "apply_ecr" {
  for_each = var.environments

  name   = "${var.project}-${each.key}-apply-ecr"
  policy = data.aws_iam_policy_document.apply_ecr.json
}

resource "aws_iam_role_policy_attachment" "plan_ecr" {
  for_each = var.environments

  role       = aws_iam_role.plan[each.key].name
  policy_arn = aws_iam_policy.plan_ecr[each.key].arn
}

resource "aws_iam_role_policy_attachment" "apply_ecr" {
  for_each = var.environments

  role       = aws_iam_role.apply[each.key].name
  policy_arn = aws_iam_policy.apply_ecr[each.key].arn
}

# --- Release pipeline push identity (repo camp-payment-service) --------------------------------
# Separate from the environment identities: it is not tied to an environment, and it can push to
# one repository and nothing else. GetAuthorizationToken has no resource-level form, so it is the
# only action on "*".

resource "aws_iam_user" "ecr_push" {
  name = "${var.project}-ecr-push-ci"
}

data "aws_iam_policy_document" "trust_ecr_push" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.ecr_push.arn]
    }
  }
}

resource "aws_iam_role" "ecr_push" {
  name                 = "${var.project}-ecr-push"
  assume_role_policy   = data.aws_iam_policy_document.trust_ecr_push.json
  description          = "Release pipeline role: push images to ${var.ecr_repository_name} only. Assumable only by its CI user."
  max_session_duration = 3600
}

data "aws_iam_policy_document" "assume_ecr_push" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.ecr_push.arn]
  }
}

resource "aws_iam_user_policy" "ecr_push_assume" {
  name   = "assume-${var.project}-ecr-push"
  user   = aws_iam_user.ecr_push.name
  policy = data.aws_iam_policy_document.assume_ecr_push.json
}

data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid       = "AuthenticateToRegistry"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PushToOneRepository"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
    ]
    resources = [local.ecr_repo_arn]
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "${var.project}-ecr-push"
  role   = aws_iam_role.ecr_push.id
  policy = data.aws_iam_policy_document.ecr_push.json
}
