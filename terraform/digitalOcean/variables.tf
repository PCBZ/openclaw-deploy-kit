# ── DigitalOcean Auth ────────────────────────────────────────
variable "do_token" {
  sensitive = true
}

# ── SSH ──────────────────────────────────────────────────────
variable "ssh_public_key_path" {
  description = "Path to your SSH public key, e.g. ~/.ssh/id_rsa.pub"
  default     = "~/.ssh/id_rsa.pub"
}

# ── Droplet ──────────────────────────────────────────────────
variable "region" {
  description = "DigitalOcean region slug (e.g. tor1, sfo3, nyc3, sgp1, ams3)"
  default     = "tor1"
}

variable "droplet_size" {
  description = "Droplet size slug (e.g. s-1vcpu-1gb=$6, s-1vcpu-2gb=$12, s-2vcpu-2gb=$18)"
  default     = "s-1vcpu-1gb"
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH to the droplet (recommended: your current public IP as /32)."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "gateway_allowed_cidrs" {
  description = "CIDR blocks allowed to access OpenClaw gateway on port 18789."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "swap_size" {
  description = "Swap file size (e.g. 2G, 3G, 4G) — prevents OOM during npm install"
  default     = "3G"
}

# ── Secrets ──────────────────────────────────────────────────
variable "openrouter_api_key" {
  sensitive = true
}

variable "telegram_bot_token" {
  sensitive = true
}

variable "openclaw_gateway_token" {
  sensitive = true
}

variable "brave_api_key" {
  description = "Brave Search API key (free tier: 1000 req/month). Leave empty to use DuckDuckGo fallback."
  sensitive   = true
  default     = ""
}

variable "telegram_owner_id" {
  description = "Your Telegram numeric user ID (get it from @userinfobot). Grants /model and other privileged commands."
  default     = ""
}

variable "slack_app_token" {
  description = "Slack App-Level Token for Socket Mode connection (starts with 'xapp-')"
  sensitive   = true
  default     = ""
}

variable "slack_bot_token" {
  description = "Slack Bot User OAuth Token for sending messages (starts with 'xoxb-')"
  sensitive   = true
  default     = ""
}
