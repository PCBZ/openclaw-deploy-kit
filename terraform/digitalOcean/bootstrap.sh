#!/bin/bash
set -e

# ── Validate required secrets ────────────────────────────────
if [[ -z "${telegram_bot_token}" || "${telegram_bot_token}" == "" ]]; then
  echo "ERROR: telegram_bot_token is empty. Ensure 'direnv allow' is run before 'terraform apply'"
  exit 1
fi
if [[ -z "${openclaw_gateway_token}" || "${openclaw_gateway_token}" == "" ]]; then
  echo "ERROR: openclaw_gateway_token is empty. Ensure 'direnv allow' is run before 'terraform apply'"
  exit 1
fi

# ── Set required environment variables for cloud-init context ─
export HOME=/root
export USER=root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ── 1. Update system packages ────────────────────────────────
apt-get update -y

# ── 2. Add swap to prevent OOM during npm install ────────────
fallocate -l ${swap_size} /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# ── 3. Install Node.js 24 ────────────────────────────────────
curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
apt-get install -y nodejs

# ── 4. Install OpenClaw (skip onboarding, done later) ────────
export OPENCLAW_ONBOARD_NON_INTERACTIVE=1
export OPENCLAW_INSTALL_METHOD=npm
curl -fsSL https://openclaw.bot/install.sh | bash -s -- \
  --install-method npm --no-onboard

# ── 5. Install missing Telegram dependencies ─────────────────
# OpenClaw's npm install doesn't bundle these; gateway crashes without them
npm install -g grammy @grammyjs/runner @grammyjs/transformer-throttler

# ── 6. Write OpenClaw config file ────────────────────────────
mkdir -p /root/.openclaw

write_config() {
cat > /root/.openclaw/openclaw.json << JSONEOF
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
        "primary": "openrouter/deepseek/deepseek-v3.2",
        "fallbacks": [
          "openrouter/meta-llama/llama-3.3-70b-instruct:free",
          "openrouter/auto"
        ]
      },
      "models": {
        "anthropic/claude-opus-4-6":                              {"alias": "opus"},
        "anthropic/claude-sonnet-4-6":                           {"alias": "sonnet"},
        "anthropic/claude-haiku-4-5-20251001":                   {"alias": "haiku"},
        "openai/gpt-5.4":                                        {"alias": "gpt5"},
        "openai/gpt-4o":                                         {"alias": "gpt4o"},
        "openai/gpt-4o-mini":                                    {"alias": "mini"},
        "google/gemini-2.5-pro":                                 {"alias": "gemini-pro"},
        "google/gemini-2.5-flash":                               {"alias": "flash"},
        "deepseek/deepseek-v3.2":                                {"alias": "deepseek"},
        "deepseek/deepseek-r1":                                  {"alias": "r1"},
        "mistralai/devstral-small":                              {"alias": "devstral"},
        "meta-llama/llama-3.3-70b-instruct:free":                {"alias": "llama"},
        "nvidia/nemotron-3-super-120b-a12b:free":                {"alias": "nemotron"},
        "qwen/qwen3-coder:free":                                 {"alias": "coder"},
        "cognitivecomputations/dolphin-mistral-24b-venice-edition:free": {"alias": "uncensored"},
        "openrouter/auto":                                       {"alias": "auto"}
      },
      "compaction": {
        "mode": "safeguard",
        "reserveTokensFloor": 20000
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
        "/usr/lib/node_modules/openclaw/dist/extensions/telegram"
      ]
    },
    "entries": {
      "telegram": { "enabled": true },
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
          "dmPolicy": "open",
          "groupPolicy": "open"${telegram_owner_id != "" ? ",\n          \"allowFrom\": [\"${telegram_owner_id}\"]" : ""}
        }
      }
    }
  }
}
JSONEOF
}

write_config

# ── 7. Write environment variables ───────────────────────────
cat > /root/.openclaw/.env << ENVEOF
OPENROUTER_API_KEY=${openrouter_api_key}
TELEGRAM_BOT_TOKEN=${telegram_bot_token}
OPENCLAW_GATEWAY_TOKEN=${openclaw_gateway_token}
BRAVE_API_KEY=${brave_api_key}
OPENCLAW_ONBOARD_NON_INTERACTIVE=1
ENVEOF

# ── 8. Export env vars for subsequent commands ───────────────
export OPENROUTER_API_KEY=${openrouter_api_key}
export TELEGRAM_BOT_TOKEN=${telegram_bot_token}
export OPENCLAW_GATEWAY_TOKEN=${openclaw_gateway_token}
export BRAVE_API_KEY=${brave_api_key}

# ── 9. Install Telegram plugin ───────────────────────────────
openclaw plugins install @openclaw/telegram

# ── 10. Auto-fix common config issues ────────────────────────
openclaw doctor --fix || true

# ── 11. Enable systemd user services for root (required in cloud-init) ──
# cloud-init has no active login session; linger + XDG_RUNTIME_DIR are needed
# for systemctl --user to work.
loginctl enable-linger root
export XDG_RUNTIME_DIR=/run/user/0
mkdir -p "$XDG_RUNTIME_DIR"
systemctl start user@0.service || true

# ── 12. Non-interactive onboard + install systemd daemon ─────
openclaw onboard --non-interactive --accept-risk --install-daemon

# ── 13. Restore config (onboard may have modified it) ────────
write_config

# ── 13.5. Clear agent cache to ensure fresh model list ───────
# This ensures Telegram plugin loads all available models (not just free ones)
rm -rf /root/.openclaw/agents

# ── 14. Sync gateway token to systemd unit ───────────────────
# This bakes the correct OPENCLAW_GATEWAY_TOKEN into the service file,
# preventing the "gateway token mismatch" loop on restart.
openclaw gateway install --force

# ── 15. Reload systemd and start gateway ─────────────────────
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway.service

# ── 16. Auto-approve Telegram Native Approvals scope ─────────
# After the gateway starts, the Telegram plugin requests an upgrade from
# operator.read -> operator.approvals. Without approval, privileged commands
# like /model return "You are not authorized". We wait for the pending
# request to appear in devices/pending.json, approve it, then restart.
echo "Waiting for Telegram Native Approvals pairing request..."
sleep 35

python3 << 'PYEOF'
import json, sys, time

PENDING_FILE = "/root/.openclaw/devices/pending.json"
PAIRED_FILE  = "/root/.openclaw/devices/paired.json"

# Wait up to 60s for a pending request
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
    print("No pending pairing requests found — skipping approval step")
    sys.exit(0)

request   = list(pending.values())[0]
device_id = request.get("deviceId")
print(f"Approving operator.approvals for device: {device_id}")

with open(PAIRED_FILE) as f:
    paired = json.load(f)

if device_id not in paired:
    print(f"Device {device_id} not in paired.json — skipping")
    sys.exit(0)

device = paired[device_id]
for key in ("scopes", "approvedScopes"):
    if "operator.approvals" not in device.get(key, []):
        device.setdefault(key, []).append("operator.approvals")

with open(PAIRED_FILE, "w") as f:
    json.dump(paired, f, indent=2)
print(f"paired.json updated — scopes: {device['scopes']}")

with open(PENDING_FILE, "w") as f:
    json.dump({}, f)
print("pending.json cleared")
PYEOF

# Restart so gateway picks up the newly approved scope
systemctl --user restart openclaw-gateway.service
echo "Gateway restarted with operator.approvals approved."

echo "OpenClaw setup complete!"