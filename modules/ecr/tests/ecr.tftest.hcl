mock_provider "aws" {}

variables {
  project         = "camp"
  environment     = "shared"
  repository_name = "camp/payment-service"
}

run "tags_are_immutable" {
  command = plan

  assert {
    condition     = aws_ecr_repository.this.image_tag_mutability == "IMMUTABLE"
    error_message = "tags must be immutable: a re-push of an existing tag must be rejected."
  }
}

run "scans_on_push" {
  command = plan

  assert {
    condition     = aws_ecr_repository.this.image_scanning_configuration[0].scan_on_push == true
    error_message = "every pushed image must be scanned."
  }
}

run "encrypted_with_managed_key" {
  command = plan

  assert {
    condition     = aws_ecr_repository.this.encryption_configuration[0].encryption_type == "AES256"
    error_message = "repository encryption must be AES256 to match the state bucket."
  }
}

run "repository_is_not_force_deletable" {
  command = plan

  assert {
    condition     = aws_ecr_repository.this.force_delete == false
    error_message = "the repository must not be deletable while it still holds images."
  }
}

run "lifecycle_expires_untagged_and_caps_count" {
  command = plan

  assert {
    condition = (
      jsondecode(aws_ecr_lifecycle_policy.this.policy).rules[0].selection.tagStatus == "untagged" &&
      jsondecode(aws_ecr_lifecycle_policy.this.policy).rules[1].selection.countNumber == 30
    )
    error_message = "lifecycle must expire untagged images and cap the total image count."
  }
}

run "rejects_uppercase_names" {
  command = plan

  variables {
    repository_name = "Payment_Service"
  }

  expect_failures = [var.repository_name]
}
