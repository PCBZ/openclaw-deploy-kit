locals {
  effective_container_image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.ghcr_remote_repository_id}/${var.ghcr_image_path}:${var.ghcr_image_tag}"

  openclaw_json_content = templatefile("${path.module}/../shared/openclaw.json.tpl", {
    openclaw_gateway_token = var.openclaw_gateway_token
    openrouter_api_key     = var.openrouter_api_key
    brave_api_key          = var.brave_api_key
    telegram_bot_token     = var.telegram_bot_token
    slack_app_token        = var.slack_app_token
    slack_bot_token        = var.slack_bot_token
    slack_enabled          = true   # Cloud Run always provisions Slack secrets
    bonjour_enabled        = true   # Cloud Run: disable bonjour discovery
    use_plugin_load_paths  = false  # Cloud Run: extensions bundled in container image
  })
}

resource "google_project_service" "required" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com"
  ])

  project                    = var.project_id
  service                    = each.key
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_artifact_registry_repository" "ghcr_remote" {
  project       = var.project_id
  location      = var.region
  repository_id = var.ghcr_remote_repository_id
  description   = var.ghcr_remote_repository_description
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"

  remote_repository_config {
    description = "GitHub Container Registry proxy"
    docker_repository {
      custom_repository {
        uri = var.ghcr_upstream_uri
      }
    }
  }

  depends_on = [google_project_service.required]
}

resource "google_artifact_registry_repository_iam_member" "ghcr_remote_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.ghcr_remote.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.cloudrun.email}"
}
