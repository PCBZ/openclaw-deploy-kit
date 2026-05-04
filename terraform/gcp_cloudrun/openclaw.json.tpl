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
    "entries": {
      "bonjour": { "enabled": false },
      "telegram": { "enabled": true },
      "slack": { "enabled": true },
      "openrouter": { "enabled": true },
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
      "allowFrom": ["*"],
      "accounts": {
        "default": {
          "botToken": "${telegram_bot_token}",
          "allowFrom": ["*"],
          "dmPolicy": "open",
          "groupPolicy": "open"
        }
      }
    },
    "slack": {
      "enabled": true,
      "mode": "socket",
      "allowFrom": ["*"],
      "appToken": "${slack_app_token}",
      "botToken": "${slack_bot_token}",
      "dmPolicy": "open",
      "groupPolicy": "open"
    }
  }
}
