#!/bin/bash
set -e

export HOME=/root
export USER=root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ── 1. System setup ──────────────────────────────────────────
apt-get update -y

# ── Create swap with temp-disk fallback ──────────────────────
swap_size_gb=${swap_size}
swap_size_mb=$((swap_size_gb * 1024))
swap_path="/mnt/resource/swapfile"
if [ ! -d "/mnt/resource" ]; then
    swap_path="/swapfile"
fi

echo "Setting up $${swap_size_gb}GB swap at $${swap_path}..."
if dd if=/dev/zero of="$${swap_path}" bs=1M count="$${swap_size_mb}"; then
    chmod 600 "$${swap_path}"
    mkswap "$${swap_path}"
    swapon "$${swap_path}"
    if ! grep -q "$${swap_path} none swap" /etc/fstab; then
        echo "$${swap_path} none swap sw 0 0" >> /etc/fstab
    fi
else
    echo "WARNING: Swap creation failed; continuing without swap."
fi

# ── Kernel swappiness tuning ─────────────────────────────────
cat > /etc/sysctl.d/99-swappiness.conf << 'SYSCTLEOF'
vm.swappiness = 20
vm.overcommit_memory = 1
SYSCTLEOF
sysctl -p /etc/sysctl.d/99-swappiness.conf

# ── Install Node.js 24.x ────────────────────────────────────
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

# Write injected openclaw.json (provided by Terraform)
cat > /root/.openclaw/openclaw.json << 'JSONEOF'
${openclaw_json_content}
JSONEOF

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
cat > /root/.openclaw/.env << 'ENVEOF'
OPENROUTER_API_KEY=${openrouter_api_key}
TELEGRAM_BOT_TOKEN=${telegram_bot_token}
OPENCLAW_GATEWAY_TOKEN=${openclaw_gateway_token}
BRAVE_API_KEY=${brave_api_key}
OPENCLAW_ONBOARD_NON_INTERACTIVE=1
ENVEOF

export OPENROUTER_API_KEY=${openrouter_api_key}
export TELEGRAM_BOT_TOKEN=${telegram_bot_token}
export OPENCLAW_GATEWAY_TOKEN=${openclaw_gateway_token}
export BRAVE_API_KEY=${brave_api_key}

# ── 5. Onboard ───────────────────────────────────────────────
openclaw doctor --fix || true

loginctl enable-linger root
export XDG_RUNTIME_DIR=/run/user/0
mkdir -p "$XDG_RUNTIME_DIR"
systemctl start user@0.service || true

openclaw onboard --non-interactive --accept-risk --install-daemon || true

# Fix models.json baseUrl (onboard may have written wrong /v1 instead of /api/v1)
MODELS_JSON=/root/.openclaw/agents/main/agent/models.json
if [ -f "$MODELS_JSON" ]; then
  sed -i 's|https://openrouter.ai/v1|https://openrouter.ai/api/v1|g' "$MODELS_JSON"
  echo "Fixed models.json baseUrl: /v1 -> /api/v1"
fi

# ── Write agent auth-profiles (OpenRouter key) ───────────────
mkdir -p /root/.openclaw/agents/main/agent
cat > /root/.openclaw/agents/main/agent/auth-profiles.json << 'AUTHEOF'
{
  "openrouter": {
    "apiKey": "${openrouter_api_key}"
  }
}
AUTHEOF

openclaw gateway install --force

# ── 6. Create systemd service override with memory limits ────
mkdir -p /root/.config/systemd/user/openclaw-gateway.service.d
cat > /root/.config/systemd/user/openclaw-gateway.service.d/override.conf << 'OVERRIDEEOF'
[Service]
TimeoutStartSec=180
TimeoutStopSec=60
RestartSec=5
MemoryLimit=${openclaw_memory_limit_mb}M
OVERRIDEEOF

systemctl --user daemon-reload
systemctl --user restart openclaw-gateway.service

# ── 7. Auto-approve operator.approvals scope ─────────────────
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

# Even if no pending requests, approve operator.approvals for all paired devices.
try:
    with open(PAIRED_FILE) as f:
        paired = json.load(f)
except Exception:
    paired = {}

for request in pending.values():
    device_id = request.get("deviceId")
    if device_id in paired:
        for key in ("scopes", "approvedScopes"):
            if "operator.approvals" not in paired[device_id].get(key, []):
                paired[device_id].setdefault(key, []).append("operator.approvals")
        print(f"Approved via pending: {device_id}")

# Ensure all paired operator devices have operator.approvals regardless of pending state
for device_id, device in paired.items():
    if "operator" in device.get("roles", []):
        for key in ("scopes", "approvedScopes"):
            if "operator.approvals" not in device.get(key, []):
                device.setdefault(key, []).append("operator.approvals")
                print(f"Granted operator.approvals to {device_id[:16]}...")

if paired:
    with open(PAIRED_FILE, "w") as f:
        json.dump(paired, f, indent=2)
if pending:
    with open(PENDING_FILE, "w") as f:
        json.dump({}, f)
PYEOF

# ── 8. Setup unattended security updates ─────────────────────
apt-get install -y unattended-upgrades

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'UNATTENDEDEOF'
Unattended-Upgrade::Allowed-Origins {
    "$${distro_id}:$${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
UNATTENDEDEOF

# ── 9. Setup cleanup cron jobs ───────────────────────────────
cat > /etc/cron.d/openclaw-cleanup << 'CRONEOF'
# OpenClaw cleanup and maintenance tasks
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Weekly npm cache cleanup (Sunday 2AM UTC)
0 2 * * 0 root npm cache clean --force >> /var/log/openclaw-cleanup.log 2>&1

# Daily disk space logging (1AM UTC)
0 1 * * * root df -h > /var/log/openclaw-diskspace.log 2>&1
CRONEOF

# ── 10. Setup logrotate for OpenClaw logs ────────────────────
mkdir -p /var/log/openclaw

cat > /etc/logrotate.d/openclaw << 'LOGROTATEEOF'
/var/log/openclaw-*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 0644 root root
    missingok
}
LOGROTATEEOF

echo "=== Azure Bootstrap Complete ==="
echo "Swap: $${swap_size_gb}GB at $${swap_path}"
echo "Memory Limit: ${openclaw_memory_limit_mb}MB (systemd cgroup)"
echo "OpenClaw Web: http://localhost:18789/health (test locally)"
echo "Check systemd: systemctl --user status openclaw-gateway"
