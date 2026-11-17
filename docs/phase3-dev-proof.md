# Dev EKS proof of concept

Verified 2026-11-17 in `eu-north-1`. The dev environment demonstrated the intended path from
Terraform foundations through GitOps deployment, an internal load balancer, the payment API, and
metrics collection. AWS teardown is pending; this is not a production-readiness claim.

## Evidence

- The infrastructure repository's Phase 3 PR [#3](https://github.com/princengcobo186-sketch/camp-infra-live/pull/3)
  is merged, and [CI passed](https://github.com/princengcobo186-sketch/camp-infra-live/actions/runs/43846687268).
- The application repository's [CI](https://github.com/princengcobo186-sketch/camp-payment-service/actions/runs/43847420080)
  and [release workflow](https://github.com/princengcobo186-sketch/camp-payment-service/actions/runs/43844094943)
  passed. The release published the SHA-tagged image selected by the dev GitOps values.
- The GitOps repository's [dev overlay and observability PR](https://github.com/princengcobo186-sketch/camp-k8s-gitops/pull/5)
  was merged. Two runtime blockers were then fixed and validated: [#6](https://github.com/princengcobo186-sketch/camp-k8s-gitops/pull/6)
  permits the Prometheus chart source and creates the controller ServiceAccount; [#7](https://github.com/princengcobo186-sketch/camp-k8s-gitops/pull/7)
  configures the VPC ID required by the AWS Load Balancer Controller.
- All dev Argo applications (`root-dev`, `projects`, `aws-load-balancer-controller`,
  `kube-prometheus-stack`, and `payment-service`) reported `Synced` and `Healthy`.
- The internal ALB was `active` and its payment target was `healthy`. Requests through the ALB
  returned HTTP 200 for `/readyz` and HTTP 201 for a synthetic payment.
- A service-level replay using the same idempotency key returned HTTP 201 then HTTP 200.
- Prometheus reported the `payment-service` target `up`; queries returned the synthetic payment
  counter and HTTP request-duration samples for `/payments`. Grafana was healthy and successfully
  queried the Prometheus `payments_total` series through its configured data source.
- GitOps PRs [#2](https://github.com/princengcobo186-sketch/camp-k8s-gitops/pull/2) and
  [#3](https://github.com/princengcobo186-sketch/camp-k8s-gitops/pull/3) document a separate
  successful Argo auto-sync check on local Kind.

## Scope and limitations

This proves the dev proof of concept only. Staging/prod promotion, production availability,
alert delivery, policy hardening, and automated deployment/destruction workflows were not
validated. The payment request used synthetic data and the project's fake provider; no real
payment credentials or card data were used.

Terraform state, plans, kubeconfig contents, generated Grafana credentials, account identifiers,
operator IPs, and internal service endpoints are intentionally excluded from this public record.
