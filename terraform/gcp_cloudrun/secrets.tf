resource "google_secret_manager_secret" "openclaw_json" {
  secret_id = "${var.service_name}-openclaw-json"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "openclaw_json" {
  secret      = google_secret_manager_secret.openclaw_json.id
  secret_data = local.openclaw_json_content
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

resource "google_secret_manager_secret" "futu_telegram_bot_token" {
  secret_id = "${var.service_name}-futu-telegram-bot-token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "futu_telegram_bot_token" {
  secret      = google_secret_manager_secret.futu_telegram_bot_token.id
  secret_data = var.futu_telegram_bot_token
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
  secret_id = "${var.service_name}-brave-api-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "brave_api_key" {
  secret      = google_secret_manager_secret.brave_api_key.id
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

resource "google_secret_manager_secret" "futu_rsa_private_key" {
  secret_id = "${var.service_name}-futu-rsa-private-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "futu_rsa_private_key" {
  secret      = google_secret_manager_secret.futu_rsa_private_key.id
  secret_data = tls_private_key.futu_rsa.private_key_pem
}

resource "google_secret_manager_secret" "r2_access_key_id" {
  secret_id = "${var.service_name}-r2-access-key-id"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "r2_access_key_id" {
  secret      = google_secret_manager_secret.r2_access_key_id.id
  secret_data = var.r2_access_key_id
}

resource "google_secret_manager_secret" "r2_secret_access_key" {
  secret_id = "${var.service_name}-r2-secret-access-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "r2_secret_access_key" {
  secret      = google_secret_manager_secret.r2_secret_access_key.id
  secret_data = var.r2_secret_access_key
}
