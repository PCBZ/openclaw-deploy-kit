# ── DigitalOcean Auth ────────────────────────────────────────
variable "do_token" {
  description = "DigitalOcean personal access token — also used as DO Inference API key"
  type        = string
  sensitive   = true
}

# ── App Platform ─────────────────────────────────────────────
variable "region" {
  description = "DigitalOcean region slug (e.g. tor, sfo, nyc, sgp, ams, fra)"
  type        = string
  default     = "tor"
}

variable "instance_size" {
  description = "App Platform instance size slug. apps-s-1vcpu-1gb=$10, apps-s-1vcpu-2gb=$25, apps-s-2vcpu-4gb=$50"
  type        = string
  default     = "apps-s-1vcpu-1gb"
}

# ── Secrets ──────────────────────────────────────────────────
variable "telegram_bot_token" {
  type      = string
  sensitive = true
}

variable "openclaw_gateway_token" {
  type      = string
  sensitive = true
}

variable "brave_api_key" {
  description = "Brave Search API key. Leave empty to disable web search."
  type        = string
  sensitive   = true
  default     = ""
}

variable "telegram_owner_id" {
  description = "Your Telegram numeric user ID (get from @userinfobot). Restricts DMs to this user only."
  type        = string
  default     = ""
}

variable "mlx_base_url" {
  description = "mlx-vlm server base URL (e.g. Cloudflare Tunnel). Leave empty to disable."
  type        = string
  default     = ""
}

variable "mlx_api_key" {
  description = "mlx-vlm server API key."
  type        = string
  sensitive   = true
  default     = ""
}
