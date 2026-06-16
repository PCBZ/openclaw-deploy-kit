terraform {
  required_version = ">= 1.5.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# ── Container Registry (store our custom image) ──────────────

resource "digitalocean_container_registry" "openclaw" {
  name                   = "openclaw-registry"
  subscription_tier_slug = "starter"
  region                 = var.region
}

resource "digitalocean_container_registry_docker_credentials" "openclaw" {
  registry_name = digitalocean_container_registry.openclaw.name
}

# ── App Platform ─────────────────────────────────────────────

resource "digitalocean_app" "openclaw" {
  spec {
    name   = "openclaw-telegram"
    region = var.region

    service {
      name               = "openclaw"
      instance_count     = 1
      instance_size_slug = var.instance_size

      image {
        registry_type = "DOCR"
        registry      = digitalocean_container_registry.openclaw.name
        repository    = "openclaw-telegram"
        tag           = "latest"

        deploy_on_push {
          enabled = true
        }
      }

      # Health check via the gateway's built-in HTTP server
      http_port = 18789

      health_check {
        http_path             = "/health"
        initial_delay_seconds = 60
        period_seconds        = 30
        timeout_seconds       = 10
        failure_threshold     = 3
      }

      # ── Env vars (plain) ───────────────────────────────────
      env {
        key   = "OPENCLAW_SKIP_ONBOARDING"
        value = "1"
      }

      env {
        key   = "NODE_ENV"
        value = "production"
      }

      # ── Secrets ───────────────────────────────────────────
      env {
        key   = "OPENROUTER_API_KEY"
        value = var.openrouter_api_key
        type  = "SECRET"
      }

      env {
        key   = "TELEGRAM_BOT_TOKEN"
        value = var.telegram_bot_token
        type  = "SECRET"
      }

      env {
        key   = "OPENCLAW_GATEWAY_TOKEN"
        value = var.openclaw_gateway_token
        type  = "SECRET"
      }

      env {
        key   = "BRAVE_API_KEY"
        value = var.brave_api_key
        type  = "SECRET"
      }

      env {
        key   = "TELEGRAM_OWNER_ID"
        value = var.telegram_owner_id
      }
    }
  }
}
