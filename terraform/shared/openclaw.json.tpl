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
        "primary": "google/gemini-3.5-flash-lite"
      },
      "models": {
        "google/gemini-4-hydrogen":     {"alias": "hydrogen"},
        "google/gemini-3.5-flash":      {"alias": "flash"},
        "google/gemini-3.5-flash-lite": {"alias": "flash-lite"},
        "google/gemini-3.1-flash-lite": {"alias": "flash-3.1-lite"},
        "google/gemini-3.8-flash":      {"alias": "flash-3.8"},
        "google/gemini-3.6-flash":      {"alias": "flash-3.6"}
      },
      "compaction": { "mode": "safeguard" }
    }
  },
  "tools": {
    "web": {
      "search": { "enabled": true, "provider": "brave" },
      "fetch": { "enabled": true }
    },
    "deny": ["browser", "apply_patch"]
  },
  "plugins": {
%{ if use_plugin_load_paths ~}
    "load": {
      "paths": [
        "/usr/lib/node_modules/openclaw/dist/extensions/telegram"%{ if slack_enabled },
        "/usr/lib/node_modules/openclaw/dist/extensions/slack"%{ endif }
      ]
    },
%{ endif ~}
    "entries": {
%{ if bonjour_enabled ~}
      "bonjour": { "enabled": false },
%{ endif ~}
      "telegram": { "enabled": true },
%{ if slack_enabled ~}
      "slack": { "enabled": true },
%{ endif ~}
      "google": { "enabled": true },
      "brave": {
        "enabled": true,
        "config": { "webSearch": { "apiKey": "${brave_api_key}" } }
      }
    }
  },
  "messages": {
    "groupChat": {
      "visibleReplies": "automatic"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "accounts": {
        "default": {
          "botToken": "${telegram_bot_token}",
%{ if telegram_owner_id != "" ~}
          "allowFrom": ["${telegram_owner_id}"],
          "dmPolicy": "allowlist",
%{ else ~}
          "dmPolicy": "open",
%{ endif ~}
          "groupPolicy": "open"
        }
      }
    }%{ if slack_enabled },
    "slack": {
      "enabled": true,
      "mode": "socket",
      "allowFrom": ["*"],
      "appToken": "${slack_app_token}",
      "botToken": "${slack_bot_token}",
      "dmPolicy": "open",
      "groupPolicy": "open"
    }%{ endif }
  }
}
