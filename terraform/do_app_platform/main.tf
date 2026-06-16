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
                "fallbacks": [
                  "openrouter/anthropic/claude-haiku-4.5",
                  "openrouter/openai/gpt-oss-120b:free",
                  "openrouter/google/gemma-4-31b-it:free",
                  "openrouter/meta-llama/llama-3.3-70b-instruct:free",
                  "openrouter/auto"
                ]
              },
              "models": {
                "openrouter/anthropic/claude-opus-4.7":                                      {"alias": "opus"},
                "openrouter/anthropic/claude-sonnet-4.6":                                    {"alias": "sonnet"},
                "openrouter/anthropic/claude-haiku-4.5":                                     {"alias": "haiku"},
                "openrouter/openai/gpt-5.4":                                                 {"alias": "gpt5"},
                "openrouter/openai/gpt-4o-mini":                                             {"alias": "mini"},
                "openrouter/google/gemini-2.5-flash":                                        {"alias": "flash"},
                "openrouter/deepseek/deepseek-r1":                                           {"alias": "r1"},
                "openrouter/nvidia/nemotron-3-ultra-550b-a55b:free":                         {"alias": "nemotron-ultra"},
                "openrouter/nvidia/nemotron-3-super-120b-a12b:free":                         {"alias": "nemotron"},
                "openrouter/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free":             {"alias": "nemotron-nano"},
                "openrouter/openai/gpt-oss-120b:free":                                       {"alias": "gpt-oss"},
                "openrouter/openai/gpt-oss-20b:free":                                        {"alias": "gpt-oss-mini"},
                "openrouter/google/gemma-4-31b-it:free":                                     {"alias": "gemma"},
                "openrouter/google/gemma-4-26b-a4b-it:free":                                 {"alias": "gemma-moe"},
                "openrouter/qwen/qwen3-coder:free":                                          {"alias": "coder"},
                "openrouter/qwen/qwen3-next-80b-a3b-instruct:free":                          {"alias": "qwen3"},
                "openrouter/poolside/laguna-m.1:free":                                       {"alias": "laguna"},
                "openrouter/nex-agi/nex-n2-pro:free":                                        {"alias": "nex"},
                "openrouter/meta-llama/llama-3.3-70b-instruct:free":                         {"alias": "llama"},
                "openrouter/cognitivecomputations/dolphin-mistral-24b-venice-edition:free":  {"alias": "uncensored"},
                "openrouter/auto":                                                            {"alias": "auto"}
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
