variable "project" {
  description = "Project name."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster that uses this VPC. Subnets are tagged for it so the load balancer controller and kubelet can discover them."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR. Non-overlapping per environment so peering or VPN stays possible later."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr, 0)) && tonumber(split("/", var.cidr)[1]) <= 20
    error_message = "cidr must be a valid IPv4 CIDR no smaller than /20, so the per-AZ subnet split fits."
  }
}

variable "azs" {
  description = "Availability zones. Two or more: EKS requires subnets in at least two AZs."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "azs must list at least two availability zones."
  }
}

variable "nat_gateway_mode" {
  description = "single: one shared NAT gateway (cheap; one AZ is a failure domain). per_az: one per AZ (production)."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "per_az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be single or per_az."
  }
}
