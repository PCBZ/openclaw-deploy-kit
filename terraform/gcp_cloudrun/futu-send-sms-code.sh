#!/bin/bash
# Usage: ./futu-send-sms-code.sh <6-digit-code>

set -e

CODE="${1:-}"
if [ -z "$CODE" ]; then
  echo "Usage: $0 <sms-code>" >&2
  exit 1
fi

PROJECT=$(gcloud config get-value project 2>/dev/null)
ZONE=$(gcloud compute instances list \
  --project="$PROJECT" --filter="name~futu-opend" --format="value(zone)" | head -1)
INSTANCE=$(gcloud compute instances list \
  --project="$PROJECT" --filter="name~futu-opend" --format="value(name)" | head -1)

gcloud compute ssh "$INSTANCE" --zone="$ZONE" --project="$PROJECT" \
  -- "printf 'input_phone_verify_code -code=$CODE\r\n' | sudo nc -q 2 127.0.0.1 22222"
