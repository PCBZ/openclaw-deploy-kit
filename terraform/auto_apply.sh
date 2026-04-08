while true; do
  terraform apply -auto-approve && break
  echo "$(date): 容量不足，60秒后重试..."
  sleep 60
done