config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Enable in Phase 2, when the first AWS module lands and `tflint --init` can fetch the plugin:
# plugin "aws" {
#   enabled = true
#   version = "<pin exact>"
#   source  = "github.com/terraform-linters/tflint-ruleset-aws"
# }
