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
  description = "DigitalOcean region"
  default     = "tor1"
}

variable "droplet_size" {
  description = "Droplet size slug"
  default     = "s-1vcpu-1gb"
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