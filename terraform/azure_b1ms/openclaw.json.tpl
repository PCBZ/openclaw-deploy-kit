{
  "gateway": {
    "bind": "lan",
    "auth": { "mode": "token", "token": "${openclaw_gateway_token}" },
    "mode": "local",
    "remote": { "token": "${openclaw_gateway_token}" }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/openai/gpt-4o-mini",
        "fallbacks": [
          "openrouter/anthropic/claude-haiku-4.5",
          "openrouter/meta-llama/llama-3.3-70b-instruct:free",
          "openrouter/auto"
        ]
      },
      "models": {
        "openrouter/anthropic/claude-opus-4.6":                                        {"alias": "opus"},
        "openrouter/anthropic/claude-sonnet-4.6":                                      {"alias": "sonnet"},
        "openrouter/anthropic/claude-haiku-4.5":                                       {"alias": "haiku"},
        "openrouter/openai/gpt-5.4":                                                   {"alias": "gpt5"},
        "openrouter/openai/gpt-4o":                                                    {"alias": "gpt4o"},
        "openrouter/openai/gpt-4o-mini":                                               {"alias": "mini"},
        "openrouter/google/gemini-2.5-pro":                                            {"alias": "gemini-pro"},
        "openrouter/google/gemini-2.5-flash":                                          {"alias": "flash"},
        "openrouter/deepseek/deepseek-r1":                                             {"alias": "r1"},
        "openrouter/mistralai/devstral-small":                                         {"alias": "devstral"},
        "openrouter/meta-llama/llama-3.3-70b-instruct:free":                           {"alias": "llama"},
        "openrouter/nvidia/nemotron-3-super-120b-a12b:free":                           {"alias": "nemotron"},
        "openrouter/qwen/qwen3-coder:free":                                            {"alias": "coder"},
        "openrouter/cognitivecomputations/dolphin-mistral-24b-venice-edition:free":    {"alias": "uncensored"},
        "openrouter/auto":                                                             {"alias": "auto"}
      },
      "compaction": { "mode": "safeguard", "reserveTokensFloor": 4000 }
    }
  },
  "tools": {
    "web": {
      "search": { "enabled": true, "provider": "brave" },
      "fetch": { 
        "enabled": true,
        "strip_images": true,
        "strip_videos": true,
        "strip_css": true,
        "strip_fonts": true
      }
    },
    "deny": ["browser"]
  },
  "plugins": {
    "load": {
      "paths": [
        "/usr/lib/node_modules/openclaw/dist/extensions/telegram"%{ if slack_enabled },
        "/usr/lib/node_modules/openclaw/dist/extensions/slack"%{ endif }
      ]
    },
    "entries": {
      "telegram": { "enabled": true },
%{ if slack_enabled }
      "slack": { "enabled": true },
%{ endif }
      "openrouter": { "enabled": true },
      "brave": {
        "enabled": true,
        "config": { "webSearch": { "apiKey": "${brave_api_key}" } }
      }
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "accounts": {
        "default": {
          "botToken": "${telegram_bot_token}",
          "dmPolicy": "open",
          "groupPolicy": "open"
        }
      }
    }%{ if slack_enabled },
    "slack": {
      "enabled": true,
      "mode": "socket",
      "appToken": "${slack_app_token}",
      "botToken": "${slack_bot_token}",
      "dmPolicy": "open",
      "groupPolicy": "open"
    }%{ endif }
  }
}
