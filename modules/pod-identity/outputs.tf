output "role_arn" {
  description = "ARN of the Pod Identity role."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the Pod Identity role."
  value       = aws_iam_role.this.name
}

output "association_id" {
  description = "ID of the Pod Identity association."
  value       = aws_eks_pod_identity_association.this.association_id
}
