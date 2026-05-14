#!/bin/sh
# Install futuapi ONLY into workspace-futu/skills — never into the global managed
# skills dir (~/.openclaw/skills/).  The main agent's workspace (~/.openclaw/workspace/)
# therefore has NO skills dir and cannot discover futuapi regardless of config filtering.
mkdir -p /home/node/.openclaw/workspace-futu/skills

if [ ! -d /home/node/.openclaw/workspace-futu/skills/futuapi ]; then
  curl -fsSL https://openapi.futunn.com/skills/opend-skills.zip -o /tmp/fs.zip \
  && mkdir -p /tmp/fs-extract \
  && node -e "
    const fs=require('fs'),zl=require('zlib');
    try {
      const d=fs.readFileSync('/tmp/fs.zip');
      let o=0;
      while(o<d.length-4){
        if(d.readUInt32LE(o)!==0x04034b50)break;
        const m=d.readUInt16LE(o+8),cs=d.readUInt32LE(o+18),
              fn=d.readUInt16LE(o+26),ex=d.readUInt16LE(o+28),
              nm=d.slice(o+30,o+30+fn).toString(),
              da=o+30+fn+ex,cd=d.slice(da,da+cs);
        if(!nm.endsWith('/')){
          const p='/tmp/fs-extract/'+nm;
          fs.mkdirSync(p.slice(0,p.lastIndexOf('/')),{recursive:true});
          fs.writeFileSync(p,m===0?cd:zl.inflateRawSync(cd));
        }
        o=da+cs;
      }
    } catch(e) { process.exit(1); }
  " \
  && cp -r /tmp/fs-extract/skills/futuapi \
           /tmp/fs-extract/skills/install-futu-opend \
           /home/node/.openclaw/workspace-futu/skills/ 2>/dev/null
  rm -rf /tmp/fs.zip /tmp/fs-extract
fi

# No workspace/skills symlink for the main agent — this is intentional.
# The main agent's workspace (~/.openclaw/workspace/) has no skills/ directory,
# so futuapi is physically unreachable from it.
mkdir -p /home/node/.local/bin
curl -LsSf https://astral.sh/uv/install.sh \
  | UV_INSTALL_DIR=/home/node/.local/bin sh
UV=/home/node/.local/bin/uv
$UV python install 3.11
$UV venv /home/node/.futu-venv --python 3.11
$UV pip install futu-api cryptography --python /home/node/.futu-venv/bin/python
printf '#!/bin/sh\nexec /home/node/.futu-venv/bin/python "$@"\n' > /home/node/.local/bin/python
printf '#!/bin/sh\nexec /home/node/.futu-venv/bin/python "$@"\n' > /home/node/.local/bin/python3
chmod +x /home/node/.local/bin/python /home/node/.local/bin/python3
export PATH=/home/node/.local/bin:$PATH
export PYTHONPATH=/home/node/.futu-venv/lib/python3.11/site-packages${PYTHONPATH:+:$PYTHONPATH}

# Write RSA private key as PKCS#1 (futu SDK requires -----BEGIN RSA PRIVATE KEY-----)
# tls_private_key generates PKCS#8; convert using Python cryptography
if [ -n "$FUTU_RSA_PRIVATE_KEY" ]; then
  mkdir -p /home/node/.openclaw/credentials
  printf '%s' "$FUTU_RSA_PRIVATE_KEY" | \
    /home/node/.futu-venv/bin/python3 -c "
import sys
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
data = sys.stdin.buffer.read()
key = serialization.load_pem_private_key(data, password=None, backend=default_backend())
sys.stdout.buffer.write(key.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.TraditionalOpenSSL,
    encryption_algorithm=serialization.NoEncryption()
))
" > /home/node/.openclaw/credentials/futu-rsa-private.pem
  if ! grep -q "BEGIN RSA PRIVATE KEY" /home/node/.openclaw/credentials/futu-rsa-private.pem 2>/dev/null; then
    echo "ERROR: RSA key conversion to PKCS#1 failed - futu SDK requires -----BEGIN RSA PRIVATE KEY-----" >&2
    exit 1
  fi
  chmod 600 /home/node/.openclaw/credentials/futu-rsa-private.pem
fi

# Patch common.py: remove any old RSA block and append the current version
sed -i '/^# RSA encryption for cross-network trade connections/,$d' \
  /home/node/.openclaw/workspace-futu/skills/futuapi/scripts/common.py 2>/dev/null || true
cat >> /home/node/.openclaw/workspace-futu/skills/futuapi/scripts/common.py << 'PYEOF'

# RSA encryption for cross-network trade connections
_futu_rsa_key_file = os.path.expanduser('~/.openclaw/credentials/futu-rsa-private.pem')
if os.path.exists(_futu_rsa_key_file):
    try:
        from futu import SysConfig
        SysConfig.set_init_rsa_file(_futu_rsa_key_file)
    except Exception:
        pass
    _orig_create_trade_context = create_trade_context
    def create_trade_context(market=None, security_firm=None):
        host, port = get_opend_config()
        _check_opend_alive(host, port)
        trd_market = parse_market(market) if market else get_default_market()
        kwargs = dict(host=host, port=port, filter_trdmarket=trd_market, is_encrypt=True)
        if _sdk_supports_ai_type:
            kwargs["ai_type"] = 1
        sf = security_firm if security_firm is not None else (get_default_security_firm() or SecurityFirm.NONE)
        kwargs["security_firm"] = sf
        return OpenSecTradeContext(**kwargs)
PYEOF
