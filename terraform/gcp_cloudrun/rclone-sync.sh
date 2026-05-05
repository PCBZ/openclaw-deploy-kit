#!/bin/sh
set -e

# ── Restore from R2 on startup ────────────────────────────────
rclone sync r2:$R2_BUCKET/ /data/ --create-empty-src-dirs 2>/dev/null || true
# Fix permissions: rclone runs as root, openclaw runs as node (uid 1000).
# Make all restored files/dirs world-writable so openclaw can write to them.
chmod -R a+rwX /data/ 2>/dev/null || true
touch /tmp/rclone-ready
echo "rclone: initial restore complete"

# ── Signal readiness via TCP 8081 (startup_probe) ────────────
(while true; do nc -l -p 8081 2>/dev/null || nc -l 8081 2>/dev/null; done) &

# ── Final sync on shutdown (SIGTERM) ─────────────────────────
cleanup() {
  echo "rclone: final sync on shutdown..."
  # Use copy (not sync) to avoid deleting files written by other instances
  rclone copy /data/ r2:$R2_BUCKET/ 2>/dev/null || true
  exit 0
}
trap cleanup TERM INT

# ── Periodic sync every 60s ───────────────────────────────────
# Use copy (not sync): sync is destructive and would delete remote files
# written by concurrent instances when max_instances > 1.
while true; do
  sleep 60
  rclone copy /data/ r2:$R2_BUCKET/ 2>/dev/null || true
done
