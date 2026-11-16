mock_provider "aws" {}

variables {
  project      = "camp"
  environment  = "dev"
  cluster_name = "camp-dev"
  cidr         = "10.20.0.0/16"
  azs          = ["eu-north-1a", "eu-north-1b"]
}

run "subnets_are_derived_from_cidr" {
  command = plan

  assert {
    condition     = output.private_subnet_cidrs == ["10.20.0.0/20", "10.20.16.0/20"]
    error_message = "private subnets must be the /20s at the start of the VPC range."
  }
}

run "public_subnets_sit_in_upper_range" {
  command = plan

  assert {
    condition     = output.public_subnet_cidrs == ["10.20.128.0/24", "10.20.129.0/24"]
    error_message = "public subnets must be /24s in the upper part of the range, clear of the private /20s."
  }
}

run "single_nat_in_single_mode" {
  command = plan

  variables {
    nat_gateway_mode = "single"
  }

  assert {
    condition     = output.nat_gateway_count == 1
    error_message = "single mode must use one shared NAT gateway."
  }
}

run "per_az_nat_in_per_az_mode" {
  command = plan

  variables {
    nat_gateway_mode = "per_az"
  }

  assert {
    condition     = output.nat_gateway_count == 2
    error_message = "per_az mode must create one NAT gateway per AZ."
  }
}

run "rejects_single_az" {
  command = plan

  variables {
    azs = ["eu-north-1a"]
  }

  expect_failures = [var.azs]
}

run "rejects_too_small_cidr" {
  command = plan

  variables {
    cidr = "10.20.0.0/24"
  }

  expect_failures = [var.cidr]
}
