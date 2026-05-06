#!/bin/sh
set -e

# openclaw.json is platform-specific (Cloud Run vs VM have different plugin config).
# Exclude it from all sync operations so platforms can share the same R2 bucket
# for soul/memory/sessions without overwriting each other's config.
RCLONE_EXCLUDE="--exclude openclaw.json --exclude openclaw.json.bak"

# ── Restore from R2 on startup ────────────────────────────────
rclone sync r2:$R2_BUCKET/ /data/ --create-empty-src-dirs $RCLONE_EXCLUDE 2>/dev/null || true
# Fix permissions: rclone runs as root, openclaw runs as node (uid 1000).
chmod -R a+rwX /data/ 2>/dev/null || true
touch /tmp/rclone-ready
echo "rclone: initial restore complete"

# ── Signal readiness via TCP 8081 (startup_probe) ────────────
(while true; do nc -l -p 8081 2>/dev/null || nc -l 8081 2>/dev/null; done) &

# ── Final sync on shutdown (SIGTERM) ─────────────────────────
cleanup() {
  echo "rclone: final sync on shutdown..."
  rclone copy /data/ r2:$R2_BUCKET/ --create-empty-src-dirs $RCLONE_EXCLUDE 2>/dev/null || true
  exit 0
}
trap cleanup TERM INT

# ── Periodic sync every 60s ───────────────────────────────────
while true; do
  sleep 60
  rclone copy /data/ r2:$R2_BUCKET/ --create-empty-src-dirs $RCLONE_EXCLUDE 2>/dev/null || true
done
