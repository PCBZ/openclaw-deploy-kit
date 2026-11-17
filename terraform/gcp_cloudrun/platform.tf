locals {
  effective_container_image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.ghcr_remote_repository_id}/${var.ghcr_image_path}:${var.ghcr_image_tag}"

  openclaw_json_base = templatefile("${path.module}/../shared/openclaw.json.tpl", {
    openclaw_gateway_token = var.openclaw_gateway_token
    brave_api_key          = var.brave_api_key
    telegram_bot_token     = var.telegram_bot_token
    slack_app_token        = var.slack_app_token
    slack_bot_token        = var.slack_bot_token
    slack_enabled          = true  # Cloud Run always provisions Slack secrets
    bonjour_enabled        = true  # Cloud Run: disable bonjour discovery
    use_plugin_load_paths  = false # Cloud Run: extensions bundled in container image
    telegram_owner_id      = var.telegram_owner_id
  })

  # Telegram webhook mode: patched onto the rendered shared template so the other
  # stacks that share it are unaffected. Uses the deterministic Cloud Run URL
  # (service-PROJECTNUMBER.REGION.run.app) to avoid a dependency cycle with the service.
  telegram_webhook_url    = "https://${var.service_name}-${data.google_project.this.number}.${var.region}.run.app/telegram-webhook"
  telegram_webhook_secret = substr(sha256("${var.openclaw_gateway_token}:telegram-webhook"), 0, 48)
  openclaw_json_parsed    = jsondecode(local.openclaw_json_base)

  openclaw_json_content = var.telegram_webhook_enabled ? jsonencode(merge(local.openclaw_json_parsed, {
    channels = merge(local.openclaw_json_parsed.channels, {
      telegram = merge(local.openclaw_json_parsed.channels.telegram, {
        webhookUrl    = local.telegram_webhook_url
        webhookSecret = local.telegram_webhook_secret
        webhookPath   = "/telegram-webhook"
      })
    })
  })) : local.openclaw_json_base
}

data "google_project" "this" {
  project_id = var.project_id
}

# Telegram servers must be able to reach the webhook, so the service has to accept
# unauthenticated requests. The webhook route is protected by the secret header;
# other gateway routes still require the gateway token.
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count    = var.telegram_webhook_enabled ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.openclaw.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_project_service" "required" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudresourcemanager.googleapis.com"
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

  depends_on = [google_project_service.required]
}
