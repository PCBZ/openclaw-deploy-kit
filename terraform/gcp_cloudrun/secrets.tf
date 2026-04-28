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
  secret_id = "${var.service_name}-slack-app-token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "slack_app_token" {
  secret      = google_secret_manager_secret.slack_app_token.id
  secret_data = var.slack_app_token
}

resource "google_secret_manager_secret" "slack_bot_token" {
  secret_id = "${var.service_name}-slack-bot-token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "slack_bot_token" {
  secret      = google_secret_manager_secret.slack_bot_token.id
  secret_data = var.slack_bot_token
}
