#!/bin/bash
set -e

# ── Set required environment variables for cloud-init context ─
export HOME=/root
export USER=root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ── 1. Update system packages ────────────────────────────────
apt-get update -y

# ── 2. Add swap to prevent OOM during npm install ────────────
fallocate -l 3G /swapfile
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
        "primary": "openrouter/meta-llama/llama-3.3-70b-instruct:free",
        "fallbacks": [
          "openrouter/auto"
        ]
      },
      "models": {
        "openrouter/meta-llama/llama-3.3-70b-instruct:free": {"alias": "llama"},
        "openrouter/cognitivecomputations/dolphin-mistral-24b-venice-edition:free": {"alias": "uncensored"},
        "openrouter/google/gemini-2.0-flash-exp:free": {"alias": "gemini"},
        "openrouter/auto": {"alias": "auto"}
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
          "groupPolicy": "open"
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

# ── 11. Non-interactive onboard + install systemd daemon ─────
openclaw onboard --non-interactive --install-daemon

# ── 12. Restore config (onboard may have modified it) ────────
write_config

# ── 13. Sync gateway token to systemd unit ───────────────────
# This bakes the correct OPENCLAW_GATEWAY_TOKEN into the service file,
# preventing the "gateway token mismatch" loop on restart.
openclaw gateway install --force

# ── 14. Reload systemd and start gateway ─────────────────────
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway.service

echo "OpenClaw setup complete!"
