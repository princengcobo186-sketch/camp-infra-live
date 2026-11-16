# One role per (namespace, ServiceAccount). EKS Pod Identity needs no IAM OIDC provider, so it works
# under the account's SCP, which denies iam:*Provider*. The trust is the pods.eks.amazonaws.com
# service principal, and the association binds the role to exactly one ServiceAccount.

locals {
  role_name = "${var.project}-${var.environment}-${var.name}"
}

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "PodIdentityAssume"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = local.role_name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  description          = "Pod Identity role for ${var.namespace}/${var.service_account} in ${var.cluster_name}."
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "inline" {
  count = var.inline_policy_json == null ? 0 : 1

  name   = "${local.role_name}-inline"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.this.arn
}
