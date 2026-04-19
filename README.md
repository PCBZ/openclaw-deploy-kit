# OpenClaw on DigitalOcean

[![Security Checks](https://github.com/PCBZ/OpenClaw_Docker/actions/workflows/security.yml/badge.svg)](https://github.com/PCBZ/OpenClaw_Docker/actions/workflows/security.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/PCBZ/OpenClaw_Docker)](https://github.com/PCBZ/OpenClaw_Docker/commits/main)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-844fba?logo=terraform&logoColor=white)](https://www.terraform.io)
[![DigitalOcean](https://img.shields.io/badge/DigitalOcean-Droplet-0080ff?logo=digitalocean&logoColor=white)](https://www.digitalocean.com)
[![OpenRouter](https://img.shields.io/badge/OpenRouter-Free%20Tier-ff6b35?logoColor=white)](https://openrouter.ai)
[![OpenClaw](https://img.shields.io/badge/OpenClaw-2026-00e5cc?logoColor=white)](https://openclaw.bot)
[![Telegram](https://img.shields.io/badge/Telegram-Bot-26a5e4?logo=telegram&logoColor=white)](https://telegram.org)
[![Slack](https://img.shields.io/badge/Slack-Bot-4a154b?logo=slack&logoColor=white)](https://slack.com)

One-command deployment of an [OpenClaw](https://openclaw.bot) AI agent on DigitalOcean with Telegram support and Slack support. After `terraform apply`, the bot is fully operational with no manual SSH steps required.

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
- DigitalOcean account + API token
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

### 2. Configure infrastructure

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

```bash
terraform output ssh_command   # SSH into the server if needed
```

Send a message to your bot on Telegram to confirm it's working.

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
