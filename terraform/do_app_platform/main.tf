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

# ── Config rendered at plan time, passed as base64 env vars ──
locals {
  openclaw_config = jsonencode({
    gateway = {
      bind = "lan"
      auth = { mode = "token", token = var.openclaw_gateway_token }
      mode = "local"
    }
    agents = {
      defaults = {
        model = {
          primary   = "openrouter/openai/gpt-4o-mini"
          fallbacks = [
            "openrouter/anthropic/claude-haiku-4.5",
            "openrouter/openai/gpt-oss-120b:free",
            "openrouter/google/gemma-4-31b-it:free",
            "openrouter/meta-llama/llama-3.3-70b-instruct:free",
            "openrouter/auto"
          ]
        }
        models = {
          "openrouter/anthropic/claude-opus-4.7"                                       = { alias = "opus" }
          "openrouter/anthropic/claude-sonnet-4.6"                                     = { alias = "sonnet" }
          "openrouter/anthropic/claude-haiku-4.5"                                      = { alias = "haiku" }
          "openrouter/openai/gpt-5.4"                                                  = { alias = "gpt5" }
          "openrouter/openai/gpt-4o-mini"                                              = { alias = "mini" }
          "openrouter/google/gemini-2.5-flash"                                         = { alias = "flash" }
          "openrouter/deepseek/deepseek-r1"                                            = { alias = "r1" }
          "openrouter/nvidia/nemotron-3-ultra-550b-a55b:free"                          = { alias = "nemotron-ultra" }
          "openrouter/nvidia/nemotron-3-super-120b-a12b:free"                          = { alias = "nemotron" }
          "openrouter/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free"              = { alias = "nemotron-nano" }
          "openrouter/openai/gpt-oss-120b:free"                                        = { alias = "gpt-oss" }
          "openrouter/openai/gpt-oss-20b:free"                                         = { alias = "gpt-oss-mini" }
          "openrouter/google/gemma-4-31b-it:free"                                      = { alias = "gemma" }
          "openrouter/google/gemma-4-26b-a4b-it:free"                                  = { alias = "gemma-moe" }
          "openrouter/qwen/qwen3-coder:free"                                           = { alias = "coder" }
          "openrouter/qwen/qwen3-next-80b-a3b-instruct:free"                           = { alias = "qwen3" }
          "openrouter/poolside/laguna-m.1:free"                                        = { alias = "laguna" }
          "openrouter/nex-agi/nex-n2-pro:free"                                         = { alias = "nex" }
          "openrouter/meta-llama/llama-3.3-70b-instruct:free"                          = { alias = "llama" }
          "openrouter/cognitivecomputations/dolphin-mistral-24b-venice-edition:free"   = { alias = "uncensored" }
          "openrouter/auto"                                                             = { alias = "auto" }
        }
        compaction = { mode = "safeguard", reserveTokensFloor = 4000 }
      }
    }
    tools = {
      web = {
        search = {
          enabled  = var.brave_api_key != "" ? true : false
          provider = var.brave_api_key != "" ? "brave" : "duckduckgo"
        }
        fetch = { enabled = false }
      }
      deny = ["browser", "apply_patch"]
    }
    plugins = {
      entries = var.brave_api_key != "" ? {
        telegram   = { enabled = true }
        openrouter = { enabled = true }
        brave      = { enabled = true, config = { webSearch = { apiKey = var.brave_api_key } } }
      } : {
        telegram   = { enabled = true }
        openrouter = { enabled = true }
      }
    }
    channels = {
      telegram = {
        enabled = true
        accounts = {
          default = merge(
            {
              botToken    = var.telegram_bot_token
              dmPolicy    = var.telegram_owner_id != "" ? "allowlist" : "open"
              groupPolicy = "open"
            },
            var.telegram_owner_id != "" ? { allowFrom = [var.telegram_owner_id] } : {}
          )
        }
      }
    }
  })

  auth_profiles = jsonencode({
    openrouter = { apiKey = var.openrouter_api_key }
  })
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
        registry_type = "GHCR"
        registry      = "openclaw"
        repository    = "openclaw"
        tag           = "latest"
      }

      # Decode base64 configs, write to disk, start gateway in foreground.
      # Simple one-liner — no heredoc, no shell quoting issues.
      run_command = "sh -c 'mkdir -p $HOME/.openclaw/agents/main/agent && echo \"$OPENCLAW_CONFIG_B64\" | base64 -d > $HOME/.openclaw/openclaw.json && echo \"$OPENCLAW_AUTH_B64\" | base64 -d > $HOME/.openclaw/agents/main/agent/auth-profiles.json && node dist/index.js gateway --port 18789 --bind lan'"

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

      # Rendered configs passed as base64 — no secrets exposed in run_command
      env {
        key   = "OPENCLAW_CONFIG_B64"
        value = base64encode(local.openclaw_config)
        type  = "SECRET"
      }

      env {
        key   = "OPENCLAW_AUTH_B64"
        value = base64encode(local.auth_profiles)
        type  = "SECRET"
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
