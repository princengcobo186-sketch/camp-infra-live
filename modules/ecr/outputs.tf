output "repository_name" {
  description = "Repository name. Push targets are <account>.dkr.ecr.<region>.amazonaws.com/<name>:<tag>."
  value       = aws_ecr_repository.this.name
}

output "repository_url" {
  description = "Registry URL of the repository, without a tag."
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN of the repository, for IAM policies that grant pull or push."
  value       = aws_ecr_repository.this.arn
}
