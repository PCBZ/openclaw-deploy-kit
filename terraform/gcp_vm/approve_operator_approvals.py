#!/usr/bin/env python3
"""Grant operator.approvals on paired devices; clear processed pending requests."""
import json
import time

PENDING_FILE = "/root/.openclaw/devices/pending.json"
PAIRED_FILE = "/root/.openclaw/devices/paired.json"

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
