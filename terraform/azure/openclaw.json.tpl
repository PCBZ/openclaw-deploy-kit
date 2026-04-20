{
  "gateway": {
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "${openclaw_gateway_token}"
    },
    "mode": "local",
    "remote": {
      "token": "${openclaw_gateway_token}"
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/openai/gpt-4o-mini",
        "fallbacks": ["openrouter/auto"]
      },
      "models": {
        "openrouter/anthropic/claude-opus-4.6": {"alias": "opus"},
        "openrouter/anthropic/claude-sonnet-4.6": {"alias": "sonnet"},
        "openrouter/anthropic/claude-haiku-4.5": {"alias": "haiku"},
        "openrouter/openai/gpt-5.4": {"alias": "gpt5"},
        "openrouter/openai/gpt-4o": {"alias": "gpt4o"},
        "openrouter/openai/gpt-4o-mini": {"alias": "mini"},
        "openrouter/google/gemini-2.5-pro": {"alias": "gemini-pro"},
        "openrouter/google/gemini-2.5-flash": {"alias": "flash"},
        "openrouter/deepseek/deepseek-v3.2": {"alias": "deepseek"},
        "openrouter/deepseek/deepseek-r1": {"alias": "r1"},
        "openrouter/meta-llama/llama-3.3-70b-instruct:free": {"alias": "llama"},
        "openrouter/auto": {"alias": "auto"}
      },
      "compaction": {
        "mode": "safeguard",
        "reserveTokensFloor": 4000
      }
    }
  },
  "tools": {
    "web": {
      "search": {
        "enabled": true,
        "provider": "brave"
      },
      "fetch": {
        "enabled": false
      }
    },
    "deny": ["browser"]
  },
  "plugins": {
    "load": {
      "paths": [
        "/usr/lib/node_modules/openclaw/dist/extensions/telegram"%{if slack_app_token != "" && slack_bot_token != ""},
        "/usr/lib/node_modules/openclaw/dist/extensions/slack"%{endif}
      ]
    },
    "entries": {
      "telegram": { "enabled": true }%{if slack_app_token != "" && slack_bot_token != ""},
      "slack": { "enabled": true }%{endif},
      "openrouter": { "enabled": true },
      "brave": {
        "enabled": true,
        "config": {
          "webSearch": {
            "apiKey": "${brave_api_key}"
          }
        }
      }
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "accounts": {
        "default": {
          "botToken": "${telegram_bot_token}",
          "dmPolicy": "allowlist",
          "groupPolicy": "open"%{if telegram_owner_id != ""},
          "allowFrom": ["${telegram_owner_id}"]%{endif}
        }
      }
    }%{if slack_app_token != "" && slack_bot_token != ""},
    "slack": {
      "enabled": true,
      "mode": "socket",
      "appToken": "${slack_app_token}",
      "botToken": "${slack_bot_token}",
      "dmPolicy": "open",
      "groupPolicy": "open"
    }%{endif}
  }
}
