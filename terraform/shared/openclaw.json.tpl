{
  "gateway": {
    "bind": "lan",
    "auth": { "mode": "token", "token": "${openclaw_gateway_token}" },
    "mode": "local",
    "remote": { "token": "${openclaw_gateway_token}" }
  },
  "agents": {
    "list": [
      {
        "id": "main",
        "default": true,
        "skills": [],
        "tools": { "allow": ["web_search", "web_fetch", "message", "cron", "tts", "image", "image_generate", "video_generate", "gateway", "session_status", "sessions_list", "sessions_history", "sessions_send", "agents_list"] }
      },
      {
        "id": "futu",
        "skills": ["futuapi", "install-futu-opend"]
      }
    ],
    "defaults": {
      "model": {
        "primary": "openrouter/auto"
      },
      "models": {
        "openrouter/anthropic/claude-opus-4.7":                                        {"alias": "opus"},
        "openrouter/anthropic/claude-opus-4.6":                                        {"alias": "opus-4.6"},
        "openrouter/anthropic/claude-sonnet-4.6":                                      {"alias": "sonnet"},
        "openrouter/anthropic/claude-haiku-4.5":                                       {"alias": "haiku"},
        "openrouter/openai/gpt-5.5":                                                   {"alias": "gpt5.5"},
        "openrouter/openai/gpt-5.4":                                                   {"alias": "gpt5"},
        "openrouter/openai/gpt-5.4-mini":                                              {"alias": "mini5"},
        "openrouter/openai/gpt-4o":                                                    {"alias": "gpt4o"},
        "openrouter/openai/gpt-4o-mini":                                               {"alias": "mini"},
        "openrouter/google/gemini-2.5-pro":                                            {"alias": "gemini-pro"},
        "openrouter/google/gemini-2.5-flash":                                          {"alias": "flash"},
        "openrouter/google/gemma-4-31b-it:free":                                       {"alias": "gemma"},
        "openrouter/x-ai/grok-4.3":                                                    {"alias": "grok"},
        "openrouter/deepseek/deepseek-v4-pro":                                         {"alias": "deepseek"},
        "openrouter/deepseek/deepseek-v4-flash":                                       {"alias": "deepseek-flash"},
        "openrouter/deepseek/deepseek-r1":                                             {"alias": "r1"},
        "openrouter/qwen/qwen3.6-flash":                                               {"alias": "qwen-flash"},
        "openrouter/mistralai/devstral-small":                                         {"alias": "devstral"},
        "openrouter/meta-llama/llama-3.3-70b-instruct:free":                           {"alias": "llama"},
        "openrouter/nvidia/nemotron-3-super-120b-a12b:free":                           {"alias": "nemotron"},
        "openrouter/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free":               {"alias": "nemotron-nano"},
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
      "openrouter": { "enabled": true },
      "brave": {
        "enabled": true,
        "config": { "webSearch": { "apiKey": "${brave_api_key}" } }
      }
    }
  },
  "bindings": [
    {
      "type": "route",
      "agentId": "futu",
      "match": { "channel": "telegram", "accountId": "futu" }
    }
  ],
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
        },
        "futu": {
          "botToken": "${futu_telegram_bot_token}",
          "allowFrom": ["${telegram_owner_id}"],
          "dmPolicy": "allowlist",
          "groupPolicy": "allowlist",
          "groupAllowFrom": ["${telegram_owner_id}"]
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
