locals {
  slack_enabled = var.slack_app_token != "" && var.slack_bot_token != ""
  effective_container_image = var.container_image != "" ? var.container_image : (
    var.enable_ghcr_proxy
    ? "${var.region}-docker.pkg.dev/${var.project_id}/${var.ghcr_remote_repository_id}/${var.ghcr_image_path}:${var.ghcr_image_tag}"
    : "docker.io/openclaw/openclaw:latest"
  )

  openclaw_json_content = templatefile("${path.module}/openclaw.json.tpl", {
    openclaw_gateway_token = var.openclaw_gateway_token
    openrouter_api_key     = var.openrouter_api_key
    brave_api_key          = var.brave_api_key
    telegram_bot_token     = var.telegram_bot_token
    slack_app_token        = var.slack_app_token
    slack_bot_token        = var.slack_bot_token
    slack_enabled          = local.slack_enabled
  })
}

resource "google_artifact_registry_repository" "ghcr_remote" {
  count = var.enable_ghcr_proxy ? 1 : 0

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

resource "google_project_service" "required" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com"
  ])

  project                    = var.project_id
  service                    = each.key
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_storage_bucket" "state" {
  name                        = var.bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  depends_on = [google_project_service.required]
}

resource "google_storage_bucket_object" "openclaw_json" {
  name    = "openclaw.json"
  bucket  = google_storage_bucket.state.name
  content = local.openclaw_json_content
}

resource "google_storage_bucket_object" "workspace_keep" {
  name    = "workspace/.keep"
  bucket  = google_storage_bucket.state.name
  content = "keep"
}

resource "google_service_account" "cloudrun" {
  account_id   = "${var.service_name}-run-sa"
  display_name = "OpenClaw Cloud Run runtime"

  depends_on = [google_project_service.required]
}

resource "google_storage_bucket_iam_member" "state_rw" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cloudrun.email}"
}

resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}

resource "google_artifact_registry_repository_iam_member" "ghcr_remote_reader" {
  count = var.enable_ghcr_proxy ? 1 : 0

  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.ghcr_remote[0].repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.cloudrun.email}"
}

resource "google_secret_manager_secret" "openrouter_api_key" {
  secret_id = "${var.service_name}-openrouter-api-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "openrouter_api_key" {
  secret      = google_secret_manager_secret.openrouter_api_key.id
  secret_data = var.openrouter_api_key
}

resource "google_secret_manager_secret" "telegram_bot_token" {
  secret_id = "${var.service_name}-telegram-bot-token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "telegram_bot_token" {
  secret      = google_secret_manager_secret.telegram_bot_token.id
  secret_data = var.telegram_bot_token
}

resource "google_secret_manager_secret" "gateway_token" {
  secret_id = "${var.service_name}-gateway-token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "gateway_token" {
  secret      = google_secret_manager_secret.gateway_token.id
  secret_data = var.openclaw_gateway_token
}

resource "google_secret_manager_secret" "brave_api_key" {
  count     = var.brave_api_key != "" ? 1 : 0
  secret_id = "${var.service_name}-brave-api-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "brave_api_key" {
  count       = var.brave_api_key != "" ? 1 : 0
  secret      = google_secret_manager_secret.brave_api_key[0].id
  secret_data = var.brave_api_key
}

resource "google_secret_manager_secret" "slack_app_token" {
  count     = var.slack_app_token != "" ? 1 : 0
  secret_id = "${var.service_name}-slack-app-token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "slack_app_token" {
  count       = var.slack_app_token != "" ? 1 : 0
  secret      = google_secret_manager_secret.slack_app_token[0].id
  secret_data = var.slack_app_token
}

resource "google_secret_manager_secret" "slack_bot_token" {
  count     = var.slack_bot_token != "" ? 1 : 0
  secret_id = "${var.service_name}-slack-bot-token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "slack_bot_token" {
  count       = var.slack_bot_token != "" ? 1 : 0
  secret      = google_secret_manager_secret.slack_bot_token[0].id
  secret_data = var.slack_bot_token
}

resource "google_cloud_run_v2_service" "openclaw" {
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.cloudrun.email
    timeout         = "3600s"

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = local.effective_container_image
      command = ["/bin/sh"]
      args    = ["-lc", "openclaw gateway run --bind lan --port \"$${PORT:-8080}\" --allow-unconfigured"]

      ports {
        container_port = 8080
      }

      # First boot may stage plugin runtime deps on the mounted GCS volume.
      # Give startup probe enough budget to avoid false negatives.
      startup_probe {
        initial_delay_seconds = 5
        period_seconds        = 10
        timeout_seconds       = 5
        failure_threshold     = 60
        tcp_socket {
          port = 8080
        }
      }

      resources {
        limits = {
          cpu    = "2"
          memory = "4Gi"
        }
        cpu_idle = false
      }

      volume_mounts {
        name       = "openclaw-state"
        mount_path = "/mnt/openclaw-persist"
      }

      env {
        name  = "HOME"
        value = "/home/node"
      }

      # Runtime state stays on local ephemeral disk for fast startup.
      # Only required persistent files are read from GCS.
      env {
        name  = "OPENCLAW_STATE_DIR"
        value = "/tmp/openclaw-state"
      }

      env {
        name  = "OPENCLAW_CONFIG_PATH"
        value = "/mnt/openclaw-persist/openclaw.json"
      }

      env {
        name  = "OPENCLAW_CONFIG_HASH"
        value = md5(local.openclaw_json_content)
      }

      env {
        name  = "OPENCLAW_GATEWAY_PORT"
        value = "8080"
      }

      env {
        name = "OPENROUTER_API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.openrouter_api_key.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "TELEGRAM_BOT_TOKEN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.telegram_bot_token.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "OPENCLAW_GATEWAY_TOKEN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.gateway_token.secret_id
            version = "latest"
          }
        }
      }

      dynamic "env" {
        for_each = var.brave_api_key != "" ? [1] : []
        content {
          name = "BRAVE_API_KEY"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.brave_api_key[0].secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.slack_app_token != "" ? [1] : []
        content {
          name = "SLACK_APP_TOKEN"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.slack_app_token[0].secret_id
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.slack_bot_token != "" ? [1] : []
        content {
          name = "SLACK_BOT_TOKEN"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.slack_bot_token[0].secret_id
              version = "latest"
            }
          }
        }
      }
    }

    volumes {
      name = "openclaw-state"
      gcs {
        bucket    = google_storage_bucket.state.name
        read_only = true
      }
    }
  }

  depends_on = [
    google_artifact_registry_repository_iam_member.ghcr_remote_reader,
    google_storage_bucket_object.openclaw_json,
    google_storage_bucket_iam_member.state_rw,
    google_project_iam_member.secret_accessor
  ]
}
