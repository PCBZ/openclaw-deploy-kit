#!/bin/bash
set -e

export HOME=/root
export USER=root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ── 1. System setup ──────────────────────────────────────────
apt-get update -y

# ── Create swap file ─────────────────────────────────────────
swap_size_gb=${swap_size}
swap_size_mb=$((swap_size_gb * 1024))
swap_path="/swapfile"

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

# ── 3. Install rclone + restore from R2 ─────────────────────
%{ if r2_bucket_name != "" ~}
curl https://rclone.org/install.sh | bash

mkdir -p /root/.config/rclone
cat > /root/.config/rclone/rclone.conf << 'RCLONEEOF'
[r2]
type = s3
provider = Cloudflare
access_key_id = ${r2_access_key_id}
secret_access_key = ${r2_secret_access_key}
endpoint = https://${cloudflare_account_id}.r2.cloudflarestorage.com
RCLONEEOF

echo "Restoring OpenClaw state from R2 (${r2_bucket_name})..."
# Exclude openclaw.json: each platform maintains its own config so the same
# R2 bucket can be shared between Cloud Run and Compute Engine for failover.
rclone sync r2:${r2_bucket_name}/ /root/.openclaw/ --create-empty-src-dirs \
  --include "/workspace/MEMORY.md" --include "/workspace/soul.md" \
  --include "/workspace/user.md" --include "/workspace/AGENTS.md" \
  --include "/credentials/telegram-allowFrom.json" --include "/sessions/**" \
  --exclude "*" 2>/dev/null || true
chmod -R a+rX /root/.openclaw/ 2>/dev/null || true
echo "R2 restore complete"
%{ endif ~}

# ── 4. Write config ──────────────────────────────────────────
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
TELEGRAM_OWNER_ID=${telegram_owner_id}
OPENCLAW_GATEWAY_TOKEN=${openclaw_gateway_token}
BRAVE_API_KEY=${brave_api_key}
SLACK_APP_TOKEN=${slack_app_token}
SLACK_BOT_TOKEN=${slack_bot_token}
OPENCLAW_ONBOARD_NON_INTERACTIVE=1
ENVEOF
chmod 600 /root/.openclaw/.env

export OPENROUTER_API_KEY=${openrouter_api_key}
export TELEGRAM_BOT_TOKEN=${telegram_bot_token}
export TELEGRAM_OWNER_ID=${telegram_owner_id}
export OPENCLAW_GATEWAY_TOKEN=${openclaw_gateway_token}
export BRAVE_API_KEY=${brave_api_key}
export SLACK_APP_TOKEN=${slack_app_token}
export SLACK_BOT_TOKEN=${slack_bot_token}

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

# ── 7. Setup R2 periodic sync ────────────────────────────────
%{ if r2_bucket_name != "" ~}
# Periodic sync service: copies /root/.openclaw → R2 every 60s
cat > /etc/systemd/system/openclaw-r2-sync.service << 'R2SYNCEOF'
[Unit]
Description=OpenClaw R2 state periodic sync
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStart=/bin/sh -c 'while true; do rclone copy /root/.openclaw/ r2:${r2_bucket_name}/ --create-empty-src-dirs --include "/workspace/MEMORY.md" --include "/workspace/soul.md" --include "/workspace/user.md" --include "/workspace/AGENTS.md" --include "/credentials/telegram-allowFrom.json" --include "/sessions/**" --exclude "*" 2>/dev/null; sleep 60; done'

[Install]
WantedBy=multi-user.target
R2SYNCEOF

# Final sync on shutdown: ensures no state is lost on VM stop/reboot
cat > /etc/systemd/system/openclaw-r2-final.service << 'R2FINALEOF'
[Unit]
Description=OpenClaw R2 final sync on shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/rclone copy /root/.openclaw/ r2:${r2_bucket_name}/ --create-empty-src-dirs --include "/workspace/MEMORY.md" --include "/workspace/soul.md" --include "/workspace/user.md" --include "/workspace/AGENTS.md" --include "/credentials/telegram-allowFrom.json" --include "/sessions/**" --exclude "*"
TimeoutStartSec=30
RemainAfterExit=yes

[Install]
WantedBy=halt.target reboot.target shutdown.target
R2FINALEOF

systemctl daemon-reload
systemctl enable openclaw-r2-sync.service
systemctl start openclaw-r2-sync.service
systemctl enable openclaw-r2-final.service
echo "R2 sync configured: r2:${r2_bucket_name} (60s interval + shutdown hook)"
%{ endif ~}

# ── 8. Auto-approve operator.approvals scope ─────────────────
echo "Waiting for approval requests..."
sleep 120

mkdir -p /root/.openclaw/bootstrap
cat > /root/.openclaw/bootstrap/approve_operator_approvals.py << 'APPROVEPYEOF'
${approve_operator_script}
APPROVEPYEOF
chmod 700 /root/.openclaw/bootstrap/approve_operator_approvals.py
python3 /root/.openclaw/bootstrap/approve_operator_approvals.py

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
CRON_TZ=America/Los_Angeles

# Weekly npm cache cleanup (Sunday 2:00 Pacific)
0 2 * * 0 root npm cache clean --force >> /var/log/openclaw-cleanup.log 2>&1

# Daily disk space logging (2:00 Pacific)
0 2 * * * root df -h > /var/log/openclaw-diskspace.log 2>&1
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

echo "=== GCP Bootstrap Complete ==="
echo "Swap: $${swap_size_gb}GB at $${swap_path}"
echo "Memory Limit: ${openclaw_memory_limit_mb}MB (systemd cgroup)"
%{ if r2_bucket_name != "" ~}
echo "R2 Persistence: r2:${r2_bucket_name} (60s sync + shutdown hook)"
%{ endif ~}
echo "OpenClaw Web: http://localhost:18789/health (test locally)"
echo "Check systemd: systemctl --user status openclaw-gateway"
