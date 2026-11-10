mock_provider "helm" {}

variables {
  project                   = "test"
  environment               = "local"
  argocd_chart_version      = "10.17.1"
  argocd_apps_chart_version = "2.0.8"
  gitops_repo_url           = "https://github.com/example/camp-k8s-gitops.git"
}

run "root_app_watches_the_environment_path" {
  command = plan

  assert {
    condition     = yamldecode(helm_release.root_app.values[0]).applications["root-local"].source.path == "clusters/local"
    error_message = "root Application must watch clusters/<environment>."
  }
}

run "charts_are_pinned" {
  command = plan

  assert {
    condition     = helm_release.argocd.version == "10.17.1" && helm_release.root_app.version == "2.0.8"
    error_message = "both charts must use the exact pinned versions."
  }
}

run "installs_are_atomic" {
  command = plan

  assert {
    condition     = helm_release.argocd.atomic && helm_release.root_app.atomic
    error_message = "a failed install must roll back, not leave a half-installed Argo CD."
  }
}

run "prune_can_be_disabled_for_prod" {
  command = plan

  variables {
    environment = "prod"
    auto_prune  = false
  }

  assert {
    condition     = yamldecode(helm_release.root_app.values[0]).applications["root-prod"].syncPolicy.automated.prune == false
    error_message = "prod must not auto-prune."
  }
}

run "rejects_unpinned_chart_version" {
  command = plan

  variables {
    argocd_chart_version = "latest"
  }

  expect_failures = [var.argocd_chart_version]
}

run "rejects_non_https_repo_url" {
  command = plan

  variables {
    gitops_repo_url = "http://github.com/example/camp-k8s-gitops.git"
  }

  expect_failures = [var.gitops_repo_url]
}
