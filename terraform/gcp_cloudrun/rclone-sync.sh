#!/bin/sh
set -e

# Whitelist: only sync memory files shared across platforms.
# Config (openclaw.json, auth) is injected via Secret Manager, never stored in R2.
# Uses a filter file to avoid shell glob expansion of ** patterns.
FILTER_FILE=/tmp/rclone-filter.txt
cat > "$FILTER_FILE" << 'EOF'
+ workspace/MEMORY.md
+ workspace/SOUL.md
+ workspace/USER.md
+ workspace/AGENTS.md
+ agents/main/sessions/**
+ agents/futu/sessions/**
+ workspace-futu/MEMORY.md
+ workspace-futu/SOUL.md
+ workspace-futu/USER.md
+ workspace-futu/AGENTS.md
- *
EOF

# ── Restore from R2 on startup ────────────────────────────────
rclone sync r2:$R2_BUCKET/ /data/ --create-empty-src-dirs --filter-from "$FILTER_FILE" 2>/dev/null || true
# Fix permissions: rclone runs as root, openclaw runs as node (uid 1000).
chmod -R a+rwX /data/ 2>/dev/null || true
touch /tmp/rclone-ready
echo "rclone: initial restore complete"

# ── Signal readiness via TCP 8081 (startup_probe) ────────────
(while true; do nc -l -p 8081 2>/dev/null || nc -l 8081 2>/dev/null; done) &

# ── Final sync on shutdown (SIGTERM) ─────────────────────────
cleanup() {
  echo "rclone: final sync on shutdown..."
  rclone copy /data/ r2:$R2_BUCKET/ --create-empty-src-dirs --filter-from "$FILTER_FILE" 2>/dev/null || true
  exit 0
}
trap cleanup TERM INT

# ── Periodic sync every 60s ───────────────────────────────────
while true; do
  sleep 60
  rclone copy /data/ r2:$R2_BUCKET/ --create-empty-src-dirs --filter-from "$FILTER_FILE" 2>/dev/null || true
done
