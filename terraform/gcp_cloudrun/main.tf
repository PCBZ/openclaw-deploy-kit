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
