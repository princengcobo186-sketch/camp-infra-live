mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "AIDATESTTESTTEST"
    }
  }

  mock_data "aws_iam_session_context" {
    defaults = {
      arn        = "arn:aws:iam::123456789012:user/test"
      issuer_arn = "arn:aws:iam::123456789012:user/test"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name   = "eu-north-1"
      region = "eu-north-1"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  project            = "camp"
  environment        = "dev"
  cluster_name       = "camp-dev"
  kubernetes_version = "1.37"
  vpc_id             = "vpc-00000000000000000"
  private_subnet_ids = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]
}

run "public_endpoint_off_without_cidrs" {
  command = plan

  assert {
    condition     = output.public_api_enabled == false
    error_message = "with no CIDRs listed, the public API endpoint must be off."
  }
}

run "public_endpoint_on_only_for_listed_cidrs" {
  command = plan

  variables {
    endpoint_public_access_cidrs = ["203.0.113.7/32"]
  }

  assert {
    condition     = output.public_api_enabled == true
    error_message = "listing a CIDR must enable the public endpoint for that CIDR."
  }
}

run "rejects_open_public_endpoint" {
  command = plan

  variables {
    endpoint_public_access_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.endpoint_public_access_cidrs]
}

run "rejects_single_subnet" {
  command = plan

  variables {
    private_subnet_ids = ["subnet-aaaaaaaaaaaaaaaaa"]
  }

  expect_failures = [var.private_subnet_ids]
}

run "rejects_unknown_capacity_type" {
  command = plan

  variables {
    node_capacity_type = "FARGATE"
  }

  expect_failures = [var.node_capacity_type]
}

run "rejects_unpinned_kubernetes_version" {
  command = plan

  variables {
    kubernetes_version = "latest"
  }

  expect_failures = [var.kubernetes_version]
}
