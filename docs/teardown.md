# AWS proof-of-concept teardown

The dev EKS proof of concept was destroyed after its runtime checks passed. This removed the
billable test environment without deleting the Terraform backend needed to track or recreate it.

## Removed

- `live/dev/argocd-bootstrap`, `live/dev/pod-identity`, `live/dev/eks`, and `live/dev/vpc`
- The Kubernetes ingress and its controller-managed internal Application Load Balancer
- `live/shared/ecr` and its test images
- The EKS cluster, managed node group, NAT gateway, public IP, subnets, routes, and VPC

The EKS cluster encryption key is scheduled for deletion using AWS KMS's minimum seven-day
waiting period. Its deletion is pending until AWS completes that window.

## Retained

- The bootstrap S3 state bucket and versioned Terraform state objects, including the now-empty
  dev and shared stack states. This preserves an audit/recovery path and avoids orphaning the
  backend. The bucket has a small ongoing storage cost.
- Bootstrap CI IAM identities and roles. IAM identities do not incur a direct charge.
- Infrastructure code and the proof record in this repository.

Staging and prod were not applied. The local Kind environment is not an AWS resource.

## Verification

After teardown, AWS checks in `eu-north-1` found no CAMP EKS clusters, VPC, active NAT gateway,
load balancer, ECR repository, running CAMP EC2 instances, CAMP EBS volumes, or CAMP network
interfaces. The state bucket and its Terraform state objects remained available. The teardown
does not claim that unrelated resources in the AWS account were removed.
