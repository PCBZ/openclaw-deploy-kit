# OpenClaw on DigitalOcean + Azure + GCP

[![Security Checks](https://github.com/PCBZ/openclaw-deploy-kit/actions/workflows/security.yml/badge.svg)](https://github.com/PCBZ/openclaw-deploy-kit/actions/workflows/security.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/PCBZ/openclaw-deploy-kit)](https://github.com/PCBZ/openclaw-deploy-kit/commits/main)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-844fba?logo=terraform&logoColor=white)](https://www.terraform.io)
[![DigitalOcean](https://img.shields.io/badge/DigitalOcean-Droplet%20%2B%20App%20Platform-0080ff?logo=digitalocean&logoColor=white)](https://www.digitalocean.com)
[![Azure](https://img.shields.io/badge/Azure-VM-0078d4?logo=microsoft-azure&logoColor=white)](https://azure.microsoft.com)
[![GCP](https://img.shields.io/badge/GCP-Cloud%20Run%20%2B%20Compute%20Engine-4285F4?logo=googlecloud&logoColor=white)](https://cloud.google.com)
[![Cloudflare R2](https://img.shields.io/badge/Cloudflare-R2%20Persistent%20Memory-f38020?logo=cloudflare&logoColor=white)](https://developers.cloudflare.com/r2/)
[![OpenRouter](https://img.shields.io/badge/OpenRouter-Free%20Tier-ff6b35?logoColor=white)](https://openrouter.ai)
[![OpenClaw](https://img.shields.io/badge/OpenClaw-2026-00e5cc?logoColor=white)](https://openclaw.bot)
[![Telegram](https://img.shields.io/badge/Telegram-Bot-26a5e4?logo=telegram&logoColor=white)](https://telegram.org)
[![Slack](https://img.shields.io/badge/Slack-Bot-4a154b?logo=slack&logoColor=white)](https://slack.com)

One-command deployment of an [OpenClaw](https://openclaw.bot) AI agent on DigitalOcean, Azure VM, GCP VM, or GCP Cloud Run with Telegram and Slack support.

## Features

- Telegram bot with DM and group chat support
- Slack bot support (Socket Mode)
- Web search via Brave Search (falls back to DuckDuckGo)
- 15+ switchable LLM models via `/model <alias>` (GPT-4o, Claude, Gemini, Llama, DeepSeek, and more)
- **GCP Cloud Run**: persistent memory across container restarts via Cloudflare R2 (rclone sidecar syncs every 60s)
- **DO App Platform**: 23 free models via DigitalOcean Serverless Inference + optional local mlx-vlm model
- Secrets managed via `.env` + direnv — never committed

## Prerequisites

- Terraform >= 1.5
- direnv (`brew install direnv`)
- SSH key pair (for VM targets)
- DigitalOcean account + API token (for DO path)
- Azure subscription + service principal credentials (for Azure path)
- GCP project (for GCP VM or GCP Cloud Run path)
- Cloudflare account + R2 credentials (for GCP Cloud Run path only)
- OpenRouter API key (for VM/Cloud Run targets)
- Telegram bot token (from [@BotFather](https://t.me/BotFather))
- Slack App-Level token (starts with `xapp-`) — optional
- Slack Bot User OAuth token (starts with `xoxb-`) — optional

## Setup

### 1. Configure secrets

```bash
cp .env.example .env
```

Edit `.env` and fill in your values:

| Variable | Description |
|---|---|
| `DO_TOKEN` | DigitalOcean API token — also used as DO Inference key (App Platform) |
| `OPENROUTER_API_KEY` | From [openrouter.ai/keys](https://openrouter.ai/keys) — for VM/Cloud Run targets |
| `TELEGRAM_BOT_TOKEN` | From [@BotFather](https://t.me/BotFather) |
| `OPENCLAW_GATEWAY_TOKEN` | Any strong random string |
| `BRAVE_API_KEY` | From [api.search.brave.com](https://api.search.brave.com) — optional, falls back to DuckDuckGo |
| `TELEGRAM_OWNER_ID` | Your Telegram user ID from [@userinfobot](https://t.me/userinfobot) — grants `/model` and other privileged commands |
| `SLACK_APP_TOKEN` | Slack App-Level token (starts with `xapp-`) — leave empty to disable Slack |
| `SLACK_BOT_TOKEN` | Slack Bot User OAuth token (starts with `xoxb-`) — leave empty to disable Slack |
| `CF_ACCOUNT_ID` | Cloudflare Account ID — **Cloud Run only** |
| `CF_API_TOKEN` | Cloudflare API Token with R2:Edit permission — **Cloud Run only** |
| `R2_ACCESS_KEY_ID` | R2 S3-compatible Access Key ID — **Cloud Run only** |
| `R2_SECRET_ACCESS_KEY` | R2 S3-compatible Secret Access Key — **Cloud Run only** |
| `MLX_BASE_URL` | mlx-vlm server base URL e.g. `https://xxx.ngrok-free.app/v1` — **App Platform only**, optional |
| `MLX_API_KEY` | mlx-vlm server API key — **App Platform only**, optional |

### 2. Choose deployment target

---

### <span style="font-size:1.35em;font-weight:bold;">DigitalOcean</span>

[![DigitalOcean](https://img.shields.io/badge/DigitalOcean-0080ff?logo=digitalocean&logoColor=white)](https://www.digitalocean.com)

#### <span style="font-size:1.15em;font-weight:bold;">App Platform</span> *(recommended — no SSH, no VM management)*

Uses DigitalOcean Serverless Inference for LLMs — no OpenRouter key needed. DO token doubles as the inference API key.

```bash
cd terraform/do_app_platform
direnv allow
terraform init
terraform apply
```

`terraform.tfvars.example`:

```hcl
region        = "tor"   # tor, sfo, nyc, sgp, ams, fra
instance_size = "apps-s-1vcpu-1gb"  # $10/mo
```

**Available models (23 free via DO Inference):**

| Alias | Model |
|---|---|
| `flash` | DeepSeek 4 Flash *(default)* |
| `deepseek` | DeepSeek V4 Pro |
| `deepseek-3.2` | DeepSeek 3.2 |
| `r1` | DeepSeek R1 Distill Llama 70B |
| `maverick` | Llama 4 Maverick |
| `llama` | Llama 3.3 70B |
| `oss` | GPT OSS 120B (DO-hosted) |
| `oss-mini` | GPT OSS 20B (DO-hosted) |
| `qwen3` | Qwen3 32B |
| `qwen3.5` | Qwen3.5 397B |
| `qwen-coder` | Qwen3 Coder Flash |
| `nemotron-ultra` | Nemotron Ultra 550B |
| `nemotron` | Nemotron Super 120B |
| `nemotron-nano` | Nemotron Nano Omni |
| `gemma` | Gemma 4 31B |
| `kimi` | Kimi K2.6 |
| `kimi-k2.5` | Kimi K2.5 |
| `minimax` | MiniMax M2.5 |
| `mistral` | Mistral 3 14B |
| `glm` | GLM-5 |
| `arcee` | Arcee Trinity Thinking |
| `mimo` | Mimo v2.5 Pro |
| `mimo-mini` | Mimo v2.5 |

**Optional local mlx-vlm model** — run on your Mac and expose via ngrok:

```bash
mlx_vlm.server --model mlx-community/gemma-4-12B-it-4bit --port 8080
ngrok http 8080
```

Set in `.env`:
```
MLX_BASE_URL=https://xxxx.ngrok-free.app/v1
MLX_API_KEY=your-key
```

Then `terraform apply`. Use `/model local` in Telegram to switch to the local model.

#### <span style="font-size:1.15em;font-weight:bold;">Droplet</span>

```bash
cd terraform/digitalOcean
```

Edit `terraform.tfvars` to set your DigitalOcean token and optionally adjust region, droplet size, and swap:

```hcl
do_token            = "dop_v1_..."
ssh_public_key_path = "~/.ssh/id_rsa.pub"
region              = "tor1"   # tor1, sfo3, nyc3, sgp1, ams3, ...
droplet_size        = "s-1vcpu-1gb"  # $6/mo — increase if OOM
swap_size           = "3G"
```

---

### <span style="font-size:1.35em;font-weight:bold;">Azure</span>

[![Azure](https://img.shields.io/badge/Azure-VM-0078d4?logo=microsoft-azure&logoColor=white)](https://azure.microsoft.com)

#### <span style="font-size:1.15em;font-weight:bold;">Virtual Machine</span>

```bash
cd terraform/azure_vm
```

Create `terraform.tfvars` and set your Azure + VM values:

```hcl
subscription_id     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
tenant_id           = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
client_id           = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
client_secret       = "..."

resource_group_name = "your-existing-rg"
location            = "eastus"
ssh_public_key_path = "~/.ssh/id_rsa.pub"

vm_name             = "openclaw-b2pts"
vm_size             = "Standard_B2pts_v2"
os_disk_size_gb     = 30
swap_size           = 2
openclaw_memory_limit_mb = 800
```

---

### <span style="font-size:1.35em;font-weight:bold;">GCP</span>

[![GCP Compute Engine](https://img.shields.io/badge/GCP-ComputeEngine-4285F4?logo=googlecloud&logoColor=white)](https://cloud.google.com/compute)

#### <span style="font-size:1.15em;font-weight:bold;">Compute Engine</span>

```bash
cd terraform/gcp_vm
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_id = "your-gcp-project-id"
region     = "us-west1"
zone       = "us-west1-b"
vm_name    = "openclaw-e2-micro"
machine_type = "e2-micro"
boot_disk_size_gb = 30

admin_username      = "openclaw"
ssh_public_key_path = "~/.ssh/id_rsa.pub"
network_name        = "default"

# Replace with your public IP/CIDR
ssh_allowed_cidrs     = ["203.0.113.10/32"]
gateway_allowed_cidrs = ["203.0.113.10/32"]

swap_size                = 3
openclaw_memory_limit_mb = 800
```

GCP VM deployment in this repo uses:
- Compute Engine VM (default `e2-micro`, Always Free eligible)
- 30 GB boot disk
- Swap file + systemd memory cap for OpenClaw process
- Firewall rules for SSH (`22`) and OpenClaw gateway (`18789`)
- Shielded VM (Secure Boot + vTPM + Integrity Monitoring)

#### <span style="font-size:1.15em;font-weight:bold;">Cloud Run</span>

[![Cloudflare R2](https://img.shields.io/badge/Cloudflare-R2%20Persistent%20Memory-f38020?logo=cloudflare&logoColor=white)](https://developers.cloudflare.com/r2/)

```bash
cd terraform/gcp_cloudrun
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_id = "your-gcp-project-id"
region     = "us-west1"

service_name  = "openclaw"
min_instances = 1
max_instances = 3

ghcr_remote_repository_id = "ghcr-remote"
ghcr_image_path = "openclaw/openclaw"
ghcr_image_tag  = "latest"

# Cloudflare R2 — persistent memory across container restarts
cloudflare_account_id = "your-cloudflare-account-id"
cloudflare_api_token  = "your-cloudflare-api-token"
r2_access_key_id      = "your-r2-access-key-id"
r2_secret_access_key  = "your-r2-secret-access-key"
r2_bucket_name        = "openclaw-state"
```

> **Cloudflare R2 credentials** — two separate tokens are needed:
> - `cloudflare_api_token`: [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens) → Create Token → **R2:Edit** (used by Terraform to create the bucket)
> - `r2_access_key_id` + `r2_secret_access_key`: Cloudflare Dashboard → R2 → **Manage R2 API Tokens** → Create Account API Token (used by rclone at runtime)

GCP Cloud Run deployment in this repo uses:
- Cloud Run service (managed runtime, no VM SSH needed)
- Artifact Registry remote repo proxy for GHCR images
- Secret Manager for all runtime secrets
- **Cloudflare R2** for persistent state (session history, memory, soul files) — synced every 60s via rclone sidecar
- Multi-container setup: `openclaw` + `rclone-sync` sidecar sharing an emptyDir volume

---

### 3. Load secrets via direnv

```bash
# First time only
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc && source ~/.zshrc
direnv allow
```

### 4. Deploy

```bash
terraform init   # first time only
terraform apply
```

Wait ~5 minutes for bootstrap to complete. The bot will start automatically.

### 5. Verify

For VM targets (DigitalOcean Droplet / Azure VM / GCP VM):

```bash
terraform output ssh_command
```

For GCP Cloud Run target:

```bash
terraform output cloud_run_url
```

For DO App Platform:

```bash
doctl apps logs <app-id> --type=run
```

Then send a Telegram message to confirm bot response.

## Switching Models

In Telegram or Slack, use `/model <alias>`. Available aliases depend on deployment target — see the model table for your target above.

**VM / Cloud Run targets (OpenRouter):**

| Alias | Model |
|---|---|
| `opus` | Claude Opus 4 |
| `sonnet` | Claude Sonnet 4 |
| `haiku` | Claude Haiku 4 |
| `gpt4o` | GPT-4o |
| `mini` | GPT-4o mini |
| `gemini-pro` | Gemini 2.5 Pro |
| `flash` | Gemini 2.5 Flash |
| `r1` | DeepSeek R1 |
| `llama` | Llama 3.3 70B (free) |
| `auto` | OpenRouter auto-select |

## Security Notes

- `ssh_allowed_cidrs` and `gateway_allowed_cidrs` default to open (`0.0.0.0/0`). For production, restrict to your IP in `terraform.tfvars`:

```hcl
ssh_allowed_cidrs     = ["203.0.113.10/32"]
gateway_allowed_cidrs = ["203.0.113.10/32"]
```

- CI security checks are defined in [.github/workflows/security.yml](.github/workflows/security.yml) (ShellCheck, .envrc policy, Checkov, Gitleaks).
- Secrets are never written to Terraform state — all sensitive variables are injected at runtime via Secret Manager (Cloud Run) or `.env` + direnv.
