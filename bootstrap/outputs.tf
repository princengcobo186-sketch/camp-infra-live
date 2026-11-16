output "state_bucket" {
  description = "Name of the shared Terraform state bucket. live/root.hcl derives the same name from project, account and region."
  value       = aws_s3_bucket.state.id
}

output "region" {
  description = "Region the state bucket and resources live in."
  value       = var.region
}

output "apply_role_arns" {
  description = "CI apply role ARN per environment."
  value       = { for env, role in aws_iam_role.apply : env => role.arn }
}

output "plan_role_arns" {
  description = "CI plan role ARN per environment."
  value       = { for env, role in aws_iam_role.plan : env => role.arn }
}

output "ecr_push_role_arn" {
  description = "Role the release pipeline assumes to push images. Store as a repository variable in camp-payment-service."
  value       = aws_iam_role.ecr_push.arn
}

output "ci_user_names" {
  description = "IAM users that need access keys. Create each key with scripts/ci-key.sh, never through Terraform."
  value = concat(
    [for env, user in aws_iam_user.apply : user.name],
    [for env, user in aws_iam_user.plan : user.name],
    [aws_iam_user.ecr_push.name],
  )
}
