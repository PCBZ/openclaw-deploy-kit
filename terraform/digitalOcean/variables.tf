# ── DigitalOcean Auth ────────────────────────────────────────
variable "do_token" {
  sensitive = true
}

# ── SSH ──────────────────────────────────────────────────────
variable "ssh_public_key_path" {
  description = "Path to your SSH public key, e.g. ~/.ssh/id_rsa.pub"
  default     = "~/.ssh/id_rsa.pub"
}

variable "existing_ssh_key_fingerprint" {
  description = "Existing DigitalOcean SSH key fingerprint to reuse. Leave empty to create a new SSH key from ssh_public_key_path."
  default     = ""
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

variable "line_channel_access_token" {
  description = "LINE Messaging API channel access token. Leave empty to disable LINE channel."
  sensitive   = true
  default     = ""
}

variable "line_channel_secret" {
  description = "LINE Messaging API channel secret. Leave empty to disable LINE channel."
  sensitive   = true
  default     = ""
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