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
      name  = "rclone-sync"
      image = "rclone/rclone:latest"

      command = ["/bin/sh", "-c"]
      args    = [file("${path.module}/rclone-sync.sh")]

      volume_mounts {
        name       = "openclaw-runtime"
        mount_path = "/data"
      }

      env {
        name  = "RCLONE_CONFIG_R2_TYPE"
        value = "s3"
      }
      env {
        name  = "RCLONE_CONFIG_R2_PROVIDER"
        value = "Cloudflare"
      }
      env {
        name  = "RCLONE_CONFIG_R2_ENDPOINT"
        value = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
      }
      env {
        name  = "R2_BUCKET"
        value = var.r2_bucket_name
      }

      env {
        name = "RCLONE_CONFIG_R2_ACCESS_KEY_ID"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.r2_access_key_id.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "RCLONE_CONFIG_R2_SECRET_ACCESS_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.r2_secret_access_key.secret_id
            version = "latest"
          }
        }
      }

      # tcp_socket probe on port 8081 — signals readiness after initial R2 restore
      startup_probe {
        tcp_socket {
          port = 8081
        }
        initial_delay_seconds = 5
        period_seconds        = 5
        timeout_seconds       = 3
        failure_threshold     = 60
      }
    }

    containers {
      name       = "openclaw"
      depends_on = ["rclone-sync"]
      image = local.effective_container_image
      command = ["/bin/sh"]
      args    = ["-lc", "mkdir -p /home/node/.openclaw/agents/main/agent /home/node/.openclaw/credentials; [ -n \"$OPENCLAW_JSON\" ] && echo \"$OPENCLAW_JSON\" > /home/node/.openclaw/openclaw.json; [ -n \"$TELEGRAM_ALLOW_FROM\" ] && echo \"$TELEGRAM_ALLOW_FROM\" > /home/node/.openclaw/credentials/telegram-allowFrom.json; printf '{\"openrouter\":{\"apiKey\":\"%s\"}}' \"$OPENROUTER_API_KEY\" > /home/node/.openclaw/agents/main/agent/auth-profiles.json; printf '{\"providers\":{\"openrouter\":{\"baseUrl\":\"https://openrouter.ai/api/v1\",\"api\":\"openai-completions\",\"apiKey\":\"OPENROUTER_API_KEY\"}}}' > /home/node/.openclaw/agents/main/agent/models.json; exec openclaw gateway run --bind lan --port \"$${PORT:-8080}\" --allow-unconfigured"]

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "2"
          memory = "4Gi"
        }
        cpu_idle = false
      }

      volume_mounts {
        name       = "openclaw-runtime"
        mount_path = "/home/node/.openclaw"
      }

      env {
        name  = "HOME"
        value = "/home/node"
      }

      env {
        name  = "OPENCLAW_STATE_DIR"
        value = "/home/node/.openclaw"
      }

      env {
        name  = "OPENCLAW_CONFIG_PATH"
        value = "/home/node/.openclaw/openclaw.json"
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
        name = "OPENCLAW_JSON"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.openclaw_json.secret_id
            version = "latest"
          }
        }
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
        for_each = var.telegram_owner_id != "" ? [1] : []
        content {
          name = "TELEGRAM_ALLOW_FROM"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.telegram_allow_from[0].secret_id
              version = "latest"
            }
          }
        }
      }

      env {
        name = "SLACK_APP_TOKEN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.slack_app_token.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "SLACK_BOT_TOKEN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.slack_bot_token.secret_id
            version = "latest"
          }
        }
      }
    }

    volumes {
      name = "openclaw-runtime"
      empty_dir {}
    }

  }

  depends_on = [
    google_artifact_registry_repository_iam_member.ghcr_remote_reader,
    google_secret_manager_secret_version.openclaw_json,
    google_secret_manager_secret_version.telegram_allow_from,
    google_project_iam_member.secret_accessor,
    google_secret_manager_secret_version.r2_access_key_id,
    google_secret_manager_secret_version.r2_secret_access_key,
  ]
}
