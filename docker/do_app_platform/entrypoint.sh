#!/bin/sh
set -e

CONFIG_DIR="${HOME}/.openclaw"
mkdir -p "${CONFIG_DIR}/agents/main/agent" "${CONFIG_DIR}/workspace"

# ── Write openclaw.json from env vars ─────────────────────────
DM_POLICY="open"
ALLOW_FROM_BLOCK=""
if [ -n "${TELEGRAM_OWNER_ID}" ]; then
  DM_POLICY="allowlist"
  ALLOW_FROM_BLOCK=",
          \"allowFrom\": [\"${TELEGRAM_OWNER_ID}\"]"
fi

BRAVE_ENABLED="false"
BRAVE_CONFIG=""
if [ -n "${BRAVE_API_KEY}" ]; then
  BRAVE_ENABLED="true"
  BRAVE_CONFIG=",
      \"brave\": {
        \"enabled\": true,
        \"config\": { \"webSearch\": { \"apiKey\": \"${BRAVE_API_KEY}\" } }
      }"
fi

cat > "${CONFIG_DIR}/openclaw.json" << JSONEOF
{
  "gateway": {
    "bind": "all",
    "auth": { "mode": "token", "token": "${OPENCLAW_GATEWAY_TOKEN}" },
    "mode": "local"
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/openai/gpt-4o-mini",
        "fallbacks": [
          "openrouter/anthropic/claude-haiku-4.5",
          "openrouter/deepseek/deepseek-v3.2",
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
        "openrouter/deepseek/deepseek-v3.2":                                           {"alias": "deepseek"},
        "openrouter/deepseek/deepseek-r1":                                             {"alias": "r1"},
        "openrouter/meta-llama/llama-3.3-70b-instruct:free":                           {"alias": "llama"},
        "openrouter/auto":                                                              {"alias": "auto"}
      },
      "compaction": { "mode": "safeguard", "reserveTokensFloor": 4000 }
    }
  },
  "tools": {
    "web": {
      "search": { "enabled": ${BRAVE_ENABLED}, "provider": "brave" },
      "fetch": { "enabled": false }
    },
    "deny": ["browser", "apply_patch"]
  },
  "plugins": {
    "entries": {
      "telegram": { "enabled": true },
      "openrouter": { "enabled": true }${BRAVE_CONFIG}
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "accounts": {
        "default": {
          "botToken": "${TELEGRAM_BOT_TOKEN}",
          "dmPolicy": "${DM_POLICY}",
          "groupPolicy": "open"${ALLOW_FROM_BLOCK}
        }
      }
    }
  }
}
JSONEOF

# ── Write auth-profiles.json (OpenRouter API key) ─────────────
cat > "${CONFIG_DIR}/agents/main/agent/auth-profiles.json" << AUTHEOF
{
  "openrouter": {
    "apiKey": "${OPENROUTER_API_KEY}"
  }
}
AUTHEOF

# ── Write .env ────────────────────────────────────────────────
cat > "${CONFIG_DIR}/.env" << ENVEOF
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
BRAVE_API_KEY=${BRAVE_API_KEY}
OPENCLAW_ONBOARD_NON_INTERACTIVE=1
ENVEOF

# ── Write AGENTS.md instruction ───────────────────────────────
if ! grep -q "ALWAYS_REPLY_IN_DM" "${CONFIG_DIR}/workspace/AGENTS.md" 2>/dev/null; then
cat >> "${CONFIG_DIR}/workspace/AGENTS.md" << 'AGENTSEOF'

## Channel Output Rule

- ALWAYS_REPLY_IN_DM: For any direct message on Telegram, always send at least one plain-text assistant message.
- Never end a DM turn with tool calls only, empty payload, or metadata-only output.
- If uncertain, send a brief fallback: "I can help with that. Could you share a bit more detail?"
AGENTSEOF
fi

echo "Config written. Starting OpenClaw gateway..."
exec openclaw gateway start
