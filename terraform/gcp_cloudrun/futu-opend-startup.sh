#!/bin/bash
set -e

apt-get update -y
apt-get install -y curl ca-certificates libatomic1 openssl

mkdir -p /opt/opend
cd /opt/opend
curl -fsSL "https://www.futunn.com/download/fetch-lasted-link?name=opend-ubuntu" \
  -o opend.tar.gz
tar -xzf opend.tar.gz --strip-components=2 --exclude='*GUI*'
rm opend.tar.gz
chmod +x FutuOpenD

mkdir -p /root/.com.futunn.FutuOpenD/F3CNN

# Fetch RSA private key from Secret Manager (never embedded in metadata)
gcloud secrets versions access latest \
  --secret="${rsa_secret_name}" \
  --project="${project_id}" \
  > /root/futu-rsa-raw.pem

if [ ! -s /root/futu-rsa-raw.pem ]; then
  echo "ERROR: Failed to fetch RSA private key from Secret Manager" >&2
  exit 1
fi

# Convert PKCS#8 to PKCS#1 (FutuOpenD -rsa_private_key requires -----BEGIN RSA PRIVATE KEY-----)
openssl rsa -in /root/futu-rsa-raw.pem -out /root/futu-rsa-private.pem 2>&1
rm -f /root/futu-rsa-raw.pem

if ! grep -q "BEGIN RSA PRIVATE KEY" /root/futu-rsa-private.pem; then
  echo "ERROR: RSA key conversion to PKCS#1 failed" >&2
  exit 1
fi
chmod 600 /root/futu-rsa-private.pem

cat > /etc/systemd/system/futu-opend.service << 'SVCEOF'
[Unit]
Description=Futu OpenD
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Restart=always
RestartSec=10
WorkingDirectory=/opt/opend
Environment=LD_LIBRARY_PATH=/opt/opend
ExecStart=/opt/opend/FutuOpenD \
  -login_account=${futu_account} \
  -login_pwd_md5=${futu_password_md5} \
  -api_ip=0.0.0.0 \
  -api_port=11111 \
  -telnet_ip=127.0.0.1 \
  -telnet_port=22222 \
  -rsa_private_key=/root/futu-rsa-private.pem \
  -lang=en
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable futu-opend.service
systemctl start futu-opend.service
