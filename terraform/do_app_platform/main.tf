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

# ── App Platform ─────────────────────────────────────────────
# Uses the official public OpenClaw image — no custom build needed.
# Config is generated at startup from environment variables.

resource "digitalocean_app" "openclaw" {
  spec {
    name   = "openclaw-telegram"
    region = var.region

    service {
      name               = "openclaw"
      instance_count     = 1
      instance_size_slug = var.instance_size

      image {
        registry_type = "GHCR"
        registry      = "openclaw"
        repository    = "openclaw"
        tag           = "latest"
      }

      # Generate config from env vars, then start the gateway.
      # openclaw.json and auth-profiles.json are created fresh on every start.
      run_command = <<-CMD
        sh -c '
          set -e
          CONFIG="$HOME/.openclaw"
          mkdir -p "$CONFIG/agents/main/agent" "$CONFIG/workspace"

          DM_POLICY="open"
          ALLOW_FROM=""
          if [ -n "$TELEGRAM_OWNER_ID" ]; then
            DM_POLICY="allowlist"
            ALLOW_FROM=", \"allowFrom\": [\"$TELEGRAM_OWNER_ID\"]"
          fi

          BRAVE_PLUGIN=""
          if [ -n "$BRAVE_API_KEY" ]; then
            BRAVE_PLUGIN=", \"brave\": { \"enabled\": true, \"config\": { \"webSearch\": { \"apiKey\": \"$BRAVE_API_KEY\" } } }"
          fi

          cat > "$CONFIG/openclaw.json" << JSON
        {
          "gateway": {
            "bind": "all",
            "auth": { "mode": "token", "token": "$OPENCLAW_GATEWAY_TOKEN" },
            "mode": "local"
          },
          "agents": {
            "defaults": {
              "model": {
                "primary": "openrouter/openai/gpt-4o-mini",
                "fallbacks": ["openrouter/anthropic/claude-haiku-4.5", "openrouter/auto"]
              },
              "compaction": { "mode": "safeguard", "reserveTokensFloor": 4000 }
            }
          },
          "tools": {
            "web": { "search": { "enabled": true, "provider": "brave" }, "fetch": { "enabled": false } },
            "deny": ["browser", "apply_patch"]
          },
          "plugins": {
            "entries": {
              "telegram": { "enabled": true },
              "openrouter": { "enabled": true }$BRAVE_PLUGIN
            }
          },
          "channels": {
            "telegram": {
              "enabled": true,
              "accounts": {
                "default": {
                  "botToken": "$TELEGRAM_BOT_TOKEN",
                  "dmPolicy": "$DM_POLICY",
                  "groupPolicy": "open"$ALLOW_FROM
                }
              }
            }
          }
        }
        JSON

          printf "{\"openrouter\":{\"apiKey\":\"%s\"}}" "$OPENROUTER_API_KEY" \
            > "$CONFIG/agents/main/agent/auth-profiles.json"

          exec openclaw gateway start
        '
      CMD

      http_port = 18789

      health_check {
        http_path             = "/health"
        initial_delay_seconds = 60
        period_seconds        = 30
        timeout_seconds       = 10
        failure_threshold     = 3
      }

      env {
        key   = "OPENCLAW_SKIP_ONBOARDING"
        value = "1"
      }

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
