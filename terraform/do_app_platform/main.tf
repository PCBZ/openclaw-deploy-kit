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
          primary   = "do-inference/deepseek-4-flash"
          fallbacks = [
            "do-inference/llama-4-maverick",
            "do-inference/deepseek-v4-pro",
            "do-inference/openai-gpt-oss-120b",
            "do-inference/llama3.3-70b-instruct"
          ]
        }
        models = merge(
          var.mlx_base_url != "" ? {
            "mlx/mlx-community/gemma-4-12B-it-qat-4bit" = { alias = "local" }
          } : {},
          {
          # ── DeepSeek ─────────────────────────────────────
          "do-inference/deepseek-4-flash"                = { alias = "flash" }
          "do-inference/deepseek-v4-pro"                 = { alias = "deepseek" }
          "do-inference/deepseek-3.2"                    = { alias = "deepseek-3.2" }
          "do-inference/deepseek-r1-distill-llama-70b"   = { alias = "r1" }
          # ── Meta Llama ───────────────────────────────────
          "do-inference/llama-4-maverick"                = { alias = "maverick" }
          "do-inference/llama3.3-70b-instruct"           = { alias = "llama" }
          # ── OpenAI OSS (DO-hosted) ────────────────────────
          "do-inference/openai-gpt-oss-120b"             = { alias = "oss" }
          "do-inference/openai-gpt-oss-20b"              = { alias = "oss-mini" }
          # ── Qwen ─────────────────────────────────────────
          "do-inference/alibaba-qwen3-32b"               = { alias = "qwen3" }
          "do-inference/qwen3.5-397b-a17b"               = { alias = "qwen3.5" }
          "do-inference/qwen3-coder-flash"               = { alias = "qwen-coder" }
          # ── NVIDIA Nemotron ───────────────────────────────
          "do-inference/nemotron-3-ultra-550b"           = { alias = "nemotron-ultra" }
          "do-inference/nvidia-nemotron-3-super-120b"    = { alias = "nemotron" }
          "do-inference/nemotron-3-nano-omni"            = { alias = "nemotron-nano" }
          # ── Google Gemma ──────────────────────────────────
          "do-inference/gemma-4-31B-it"                  = { alias = "gemma" }
          # ── Kimi ─────────────────────────────────────────
          "do-inference/kimi-k2.6"                       = { alias = "kimi" }
          "do-inference/kimi-k2.5"                       = { alias = "kimi-k2.5" }
          # ── MiniMax ──────────────────────────────────────
          "do-inference/minimax-m2.5"                    = { alias = "minimax" }
          # ── Mistral ──────────────────────────────────────
          "do-inference/mistral-3-14B"                   = { alias = "mistral" }
          # ── GLM ──────────────────────────────────────────
          "do-inference/glm-5"                           = { alias = "glm" }
          # ── Arcee ────────────────────────────────────────
          "do-inference/arcee-trinity-large-thinking"    = { alias = "arcee" }
          # ── Mimo ─────────────────────────────────────────
          "do-inference/mimo-v2.5-pro"                   = { alias = "mimo" }
          "do-inference/mimo-v2.5"                       = { alias = "mimo-mini" }
        })
        compaction = { mode = "safeguard", reserveTokensFloor = 4000 }
      }
    }
    models = {
      providers = merge(
        var.mlx_base_url != "" ? {
          "mlx" = {
            baseUrl        = var.mlx_base_url
            apiKey         = var.mlx_api_key
            timeoutSeconds = 300
            models         = [
              { id = "mlx-community/gemma-4-12B-it-qat-4bit",  name = "Gemma 4 12B (local)" },
              { id = "mlx-community/Qwen3.5-9B-OptiQ-4bit",    name = "Qwen3.5 9B (local)" }
            ]
          }
        } : {},
        {
        "do-inference" = {
          baseUrl = "https://inference.do-ai.run/v1"
          apiKey  = var.do_token
          models = [
            { id = "deepseek-4-flash",               name = "DeepSeek 4 Flash" },
            { id = "deepseek-v4-pro",                name = "DeepSeek V4 Pro" },
            { id = "deepseek-3.2",                   name = "DeepSeek 3.2" },
            { id = "deepseek-r1-distill-llama-70b",  name = "DeepSeek R1 70B" },
            { id = "llama-4-maverick",               name = "Llama 4 Maverick" },
            { id = "llama3.3-70b-instruct",          name = "Llama 3.3 70B" },
            { id = "openai-gpt-oss-120b",            name = "GPT OSS 120B" },
            { id = "openai-gpt-oss-20b",             name = "GPT OSS 20B" },
            { id = "alibaba-qwen3-32b",              name = "Qwen3 32B" },
            { id = "qwen3.5-397b-a17b",              name = "Qwen3.5 397B" },
            { id = "qwen3-coder-flash",              name = "Qwen3 Coder Flash" },
            { id = "nemotron-3-ultra-550b",          name = "Nemotron Ultra 550B" },
            { id = "nvidia-nemotron-3-super-120b",   name = "Nemotron Super 120B" },
            { id = "nemotron-3-nano-omni",           name = "Nemotron Nano Omni" },
            { id = "gemma-4-31B-it",                 name = "Gemma 4 31B" },
            { id = "kimi-k2.6",                      name = "Kimi K2.6" },
            { id = "kimi-k2.5",                      name = "Kimi K2.5" },
            { id = "minimax-m2.5",                   name = "MiniMax M2.5" },
            { id = "mistral-3-14B",                  name = "Mistral 3 14B" },
            { id = "glm-5",                          name = "GLM-5" },
            { id = "arcee-trinity-large-thinking",   name = "Arcee Trinity Thinking" },
            { id = "mimo-v2.5-pro",                  name = "Mimo v2.5 Pro" },
            { id = "mimo-v2.5",                      name = "Mimo v2.5" }
          ]
        }
        })
    }
    tools = {
      web = {
        search = {
          enabled  = true
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
