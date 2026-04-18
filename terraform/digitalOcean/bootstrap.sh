#!/bin/bash
set -e

export HOME=/root
export USER=root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ── 1. System setup ──────────────────────────────────────────
apt-get update -y

fallocate -l ${swap_size} /swapfile
chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
apt-get install -y nodejs

# ── 2. Install OpenClaw ──────────────────────────────────────
export OPENCLAW_ONBOARD_NON_INTERACTIVE=1
export OPENCLAW_INSTALL_METHOD=npm
curl -fsSL https://openclaw.bot/install.sh | bash -s -- --install-method npm --no-onboard

npm install -g grammy @grammyjs/runner @grammyjs/transformer-throttler \
  @slack/bolt @slack/socket-mode @slack/web-api

# ── 3. Write config ──────────────────────────────────────────
mkdir -p /root/.openclaw

write_config() {
cat > /root/.openclaw/openclaw.json << JSONEOF
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
      "fetch": { "enabled": false }
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
          "groupPolicy": "open"%{if telegram_owner_id != ""},
          "allowFrom": ["${telegram_owner_id}"]%{endif}
        }
      }
    }%{if slack_app_token != "" && slack_bot_token != ""},
    "slack": {
      "enabled": true,
      "accounts": {
        "default": {
          "appToken": "${slack_app_token}",
          "botToken": "${slack_bot_token}",
          "mode": "socket",
          "dmPolicy": "open",
          "groupPolicy": "open"
        }
      }
    }%{endif}
  }
}
JSONEOF
}

write_config

mkdir -p /root/.openclaw/workspace
if ! grep -q "ALWAYS_REPLY_IN_DM" /root/.openclaw/workspace/AGENTS.md 2>/dev/null; then
cat >> /root/.openclaw/workspace/AGENTS.md << 'AGENTSEOF'

## Channel Output Rule (OpenClaw)

- ALWAYS_REPLY_IN_DM: For any direct message on Telegram/Slack, always send at least one plain-text assistant message.
- Never end a DM turn with tool calls only, empty payload, or metadata-only output.
- If uncertain, send a brief fallback text: "I can help with that. Could you share a bit more detail?"
AGENTSEOF
fi

# ── 4. Write .env and export secrets ─────────────────────────
cat > /root/.openclaw/.env << ENVEOF
OPENROUTER_API_KEY=${openrouter_api_key}
TELEGRAM_BOT_TOKEN=${telegram_bot_token}
SLACK_APP_TOKEN=${slack_app_token}
SLACK_BOT_TOKEN=${slack_bot_token}
OPENCLAW_GATEWAY_TOKEN=${openclaw_gateway_token}
BRAVE_API_KEY=${brave_api_key}
OPENCLAW_ONBOARD_NON_INTERACTIVE=1
ENVEOF

export OPENROUTER_API_KEY=${openrouter_api_key}
export TELEGRAM_BOT_TOKEN=${telegram_bot_token}
export SLACK_APP_TOKEN=${slack_app_token}
export SLACK_BOT_TOKEN=${slack_bot_token}
export OPENCLAW_GATEWAY_TOKEN=${openclaw_gateway_token}
export BRAVE_API_KEY=${brave_api_key}

# ── 5. Onboard ───────────────────────────────────────────────
openclaw doctor --fix || true

loginctl enable-linger root
export XDG_RUNTIME_DIR=/run/user/0
mkdir -p "$XDG_RUNTIME_DIR"
systemctl start user@0.service || true

openclaw onboard --non-interactive --accept-risk --install-daemon || true

# Restore config (onboard may have modified it)
write_config

# ── Write agent auth-profiles (OpenRouter key) ───────────────
# The agent reads auth from auth-profiles.json, NOT from .env
mkdir -p /root/.openclaw/agents/main/agent
python3 << AUTHEOF
import json
env = {}
with open("/root/.openclaw/.env") as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip()
key = env.get("OPENROUTER_API_KEY", "")
if key:
    path = "/root/.openclaw/agents/main/agent/auth-profiles.json"
    with open(path, "w") as f:
        json.dump({"openrouter": {"apiKey": key}}, f, indent=2)
    print(f"auth-profiles.json created (key prefix: {key[:15]}...)")
else:
    print("WARNING: OPENROUTER_API_KEY not found in .env!")
AUTHEOF

openclaw gateway install --force

mkdir -p /root/.config/systemd/user/openclaw-gateway.service.d
cat > /root/.config/systemd/user/openclaw-gateway.service.d/override.conf << 'OVERRIDEEOF'
[Service]
TimeoutStartSec=180
TimeoutStopSec=60
RestartSec=5
OVERRIDEEOF

systemctl --user daemon-reload
systemctl --user restart openclaw-gateway.service

# ── 6. Auto-approve operator.approvals scope ─────────────────
# Telegram/Slack plugins request scope upgrade after gateway starts.
# Without approval, /model returns "You are not authorized".
echo "Waiting for approval requests..."
sleep 120

python3 << 'PYEOF'
import json, sys, time

PENDING_FILE = "/root/.openclaw/devices/pending.json"
PAIRED_FILE  = "/root/.openclaw/devices/paired.json"

pending = {}
for _ in range(12):
    try:
        with open(PENDING_FILE) as f:
            pending = json.load(f)
        if pending:
            break
    except Exception:
        pass
    time.sleep(5)

if not pending:
    print("No pending requests — skipping")
    sys.exit(0)

with open(PAIRED_FILE) as f:
    paired = json.load(f)

for request in pending.values():
    device_id = request.get("deviceId")
    if device_id not in paired:
        continue
    device = paired[device_id]
    for key in ("scopes", "approvedScopes"):
        if "operator.approvals" not in device.get(key, []):
            device.setdefault(key, []).append("operator.approvals")
    print(f"Approved: {device_id}")

with open(PAIRED_FILE, "w") as f:
    json.dump(paired, f, indent=2)
with open(PENDING_FILE, "w") as f:
    json.dump({}, f)
PYEOF

systemctl --user restart openclaw-gateway.service
echo "OpenClaw setup complete!"
