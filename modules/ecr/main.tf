# Image repository for a single service. Images are built once in camp-payment-service and
# promoted by tag, so the tag must never be re-pointed at different content.
#
# IMMUTABLE tags are the guarantee behind that rule: pushing an existing tag fails instead of
# silently replacing the image every environment already runs. Tags are git SHAs, so a re-push
# of the same commit is a no-op for the pipeline and a rejection for anything else.

resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE"

  # A repository holding the only copy of promoted images must not be deleted by accident.
  force_delete = false

  image_scanning_configuration {
    scan_on_push = true
  }

  # AES256 rather than a KMS key: matches the state bucket and needs no key policy to manage.
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after ${var.untagged_expiry_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_expiry_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep at most ${var.keep_last_images} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.keep_last_images
        }
        action = { type = "expire" }
      },
    ]
  })
}
