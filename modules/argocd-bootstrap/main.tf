# Installs Argo CD and hands control of the cluster to git by creating ONE root Application that
# watches clusters/<environment> in the gitops repository (App-of-Apps). This is the only thing
# Terraform puts inside the cluster; everything after it is owned by camp-k8s-gitops.
#
# The root Application is created with the argocd-apps chart rather than a kubernetes_manifest
# because kubernetes_manifest needs the Application CRD to exist at plan time, which fails on a
# fresh cluster. Two helm_releases in order avoids that.

locals {
  # Kept small for the local Kind cluster; dex (SSO) and notifications are not needed yet.
  default_values = {
    dex           = { enabled = false }
    notifications = { enabled = false }
    configs = {
      params = {
        # TLS terminates at the ingress/port-forward, not in the pod.
        "server.insecure" = true
      }
    }
  }

  argocd_values = merge(local.default_values, var.extra_argocd_values)

  root_app_name = "root-${var.environment}"
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  atomic          = true # roll back a failed install instead of leaving a half-installed Argo CD
  cleanup_on_fail = true
  timeout         = 600

  values = [yamlencode(local.argocd_values)]
}

resource "helm_release" "root_app" {
  name      = local.root_app_name
  namespace = var.namespace

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version

  atomic = true

  values = [yamlencode({
    applications = {
      (local.root_app_name) = {
        namespace = var.namespace
        project   = "default"
        labels    = { "app.kubernetes.io/part-of" = var.project }
        source = {
          repoURL        = var.gitops_repo_url
          targetRevision = var.gitops_revision
          path           = "clusters/${var.environment}"
          directory      = { recurse = false }
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = var.namespace
        }
        syncPolicy = {
          automated = {
            prune    = var.auto_prune
            selfHeal = true
          }
        }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}
