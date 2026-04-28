# OpenClaw on DigitalOcean + Azure + GCP

[![Security Checks](https://github.com/PCBZ/OpenClaw_Docker/actions/workflows/security.yml/badge.svg)](https://github.com/PCBZ/OpenClaw_Docker/actions/workflows/security.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/PCBZ/OpenClaw_Docker)](https://github.com/PCBZ/OpenClaw_Docker/commits/main)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-844fba?logo=terraform&logoColor=white)](https://www.terraform.io)
[![DigitalOcean](https://img.shields.io/badge/DigitalOcean-Droplet-0080ff?logo=digitalocean&logoColor=white)](https://www.digitalocean.com)
[![Azure](https://img.shields.io/badge/Azure-VM-0078d4?logo=microsoft-azure&logoColor=white)](https://azure.microsoft.com)
[![GCP](https://img.shields.io/badge/GCP-ComputeEngine-4285F4?logo=googlecloud&logoColor=white)](https://cloud.google.com/compute)
[![OpenRouter](https://img.shields.io/badge/OpenRouter-Free%20Tier-ff6b35?logoColor=white)](https://openrouter.ai)
[![OpenClaw](https://img.shields.io/badge/OpenClaw-2026-00e5cc?logoColor=white)](https://openclaw.bot)
[![Telegram](https://img.shields.io/badge/Telegram-Bot-26a5e4?logo=telegram&logoColor=white)](https://telegram.org)
[![Slack](https://img.shields.io/badge/Slack-Bot-4a154b?logo=slack&logoColor=white)](https://slack.com)

One-command deployment of an [OpenClaw](https://openclaw.bot) AI agent on DigitalOcean, Azure VM, GCP VM, or GCP Cloud Run with Telegram and Slack support.

## Features

- Telegram bot with DM and group chat support
- Slack bot support (Socket Mode)
- Web search via Brave Search (falls back to DuckDuckGo)
- 8 switchable free LLM models via `/model <alias>`
- Secrets managed via `.env` — never committed

## Prerequisites

- Terraform >= 1.5
- direnv (`brew install direnv`)
- SSH key pair
- DigitalOcean account + API token (for DO path)
- Azure subscription + service principal credentials (for Azure path)
- GCP project (for GCP VM or GCP Cloud Run path)
- OpenRouter API key
- Telegram bot token (from [@BotFather](https://t.me/BotFather))
- Slack App-Level token (starts with `xapp-`)
- Slack Bot User OAuth token (starts with `xoxb-`)

## Setup

### 1. Configure secrets

```bash
cp .env.example .env
```

Edit `.env` and fill in your values:

| Variable | Description |
|---|---|
| `OPENROUTER_API_KEY` | From [openrouter.ai/keys](https://openrouter.ai/keys) |
| `TELEGRAM_BOT_TOKEN` | From [@BotFather](https://t.me/BotFather) |
| `OPENCLAW_GATEWAY_TOKEN` | Any strong random string |
| `BRAVE_API_KEY` | From [api.search.brave.com](https://api.search.brave.com) — optional, falls back to DuckDuckGo |
| `TELEGRAM_OWNER_ID` | Your Telegram user ID from [@userinfobot](https://t.me/userinfobot) — grants `/model` and other privileged commands |
| `SLACK_APP_TOKEN` | Slack App-Level token (starts with `xapp-`) |
| `SLACK_BOT_TOKEN` | Slack Bot User OAuth token (starts with `xoxb-`) |

### 2. Choose deployment target


### <span style="font-size:1.35em;font-weight:bold;">DigitalOcean</span>

[![DigitalOcean](https://img.shields.io/badge/DigitalOcean-Droplet-0080ff?logo=digitalocean&logoColor=white)](https://www.digitalocean.com)

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
- Compute Engine VM (default `e2-micro`)
- 30GB boot disk
- optional swap + systemd memory cap for OpenClaw process
- firewall rules for SSH (`22`) and OpenClaw gateway (`18789`)


#### <span style="font-size:1.15em;font-weight:bold;">Cloud Run</span>

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

bucket_name = "your-gcp-project-id-openclaw-state"
```

GCP Cloud Run deployment in this repo uses:
- Cloud Run service (managed runtime, no VM SSH needed)
- Artifact Registry remote repo proxy for GHCR images
- Secret Manager for runtime secrets
- GCS bucket for persistent state

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

For VM targets (DigitalOcean / Azure VM / GCP VM):

```bash
terraform output ssh_command
```

For GCP Cloud Run target:

```bash
terraform output cloud_run_url
```

Then:
- VM targets: SSH to the VM using the output command.
- Cloud Run target: open the Cloud Run URL from output to confirm the service is reachable.
- Send a Telegram message to confirm bot response.
- (Optional) send a Slack message if Slack tokens are configured.

## Switching Models

In Telegram, use `/model <alias>`:

All models are free tier on OpenRouter (rate limits apply).

## Security Notes

- `ssh_allowed_cidrs` and `gateway_allowed_cidrs` default to open (`0.0.0.0/0`). For production, restrict to your IP in `terraform.tfvars`:

```hcl
ssh_allowed_cidrs     = ["203.0.113.10/32"]
gateway_allowed_cidrs = ["203.0.113.10/32"]
```

- CI security checks are defined in [.github/workflows/security.yml](.github/workflows/security.yml) (ShellCheck, .envrc policy, Checkov, Gitleaks).
