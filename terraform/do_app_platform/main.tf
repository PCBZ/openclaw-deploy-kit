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
          primary   = "do-inference/openai-gpt-4o-mini"
          fallbacks = [
            "do-inference/anthropic-claude-haiku-4.5",
            "do-inference/deepseek-v4-flash",
            "do-inference/google-gemma-4",
            "do-inference/nvidia-nemotron-3-super-120b"
          ]
        }
        models = {
          # Anthropic
          "do-inference/anthropic-claude-opus-4.8"       = { alias = "opus" }
          "do-inference/anthropic-claude-4.6-sonnet"     = { alias = "sonnet" }
          "do-inference/anthropic-claude-haiku-4.5"      = { alias = "haiku" }
          # OpenAI
          "do-inference/openai-gpt-5.4"                  = { alias = "gpt5" }
          "do-inference/openai-gpt-5-mini"               = { alias = "gpt5-mini" }
          "do-inference/openai-gpt-5-nano"               = { alias = "nano" }
          "do-inference/openai-gpt-4o-mini"              = { alias = "mini" }
          "do-inference/openai-gpt-oss-120b"             = { alias = "gpt-oss" }
          "do-inference/openai-gpt-oss-20b"              = { alias = "gpt-oss-mini" }
          # Open source
          "do-inference/deepseek-v4-pro"                 = { alias = "deepseek" }
          "do-inference/deepseek-v4-flash"               = { alias = "deepseek-flash" }
          "do-inference/deepseek-r1-distill-llama-70b"   = { alias = "r1" }
          "do-inference/google-gemma-4"                  = { alias = "gemma" }
          "do-inference/nvidia-nemotron-3-ultra"         = { alias = "nemotron-ultra" }
          "do-inference/nvidia-nemotron-3-super-120b"    = { alias = "nemotron" }
          "do-inference/qwen3-32b"                       = { alias = "qwen3" }
          "do-inference/meta-llama-3.3-instruct-70b"     = { alias = "llama" }
          "do-inference/kimi-k2.6"                       = { alias = "kimi" }
        }
        compaction = { mode = "safeguard", reserveTokensFloor = 4000 }
      }
    }
    models = {
      providers = {
        "do-inference" = {
          baseUrl = "https://inference.do-ai.run/v1"
        }
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
      entries = {
        telegram = { enabled = true }
        brave = {
          enabled = var.brave_api_key != "" ? true : false
          config  = { webSearch = { apiKey = var.brave_api_key } }
        }
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
    "do-inference" = { apiKey = var.do_token }
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
