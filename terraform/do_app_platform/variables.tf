# ── DigitalOcean Auth ────────────────────────────────────────
variable "do_token" {
  type      = string
  sensitive = true
}

# ── App Platform ─────────────────────────────────────────────
variable "region" {
  description = "DigitalOcean region slug (e.g. tor, sfo, nyc, sgp, ams, fra)"
  type        = string
  default     = "tor"
}

variable "instance_size" {
  description = "App Platform instance size slug. basic-xxs=$5, basic-xs=$10, basic-s=$18"
  type        = string
  default     = "basic-xs"
}

# ── Secrets ──────────────────────────────────────────────────
variable "openrouter_api_key" {
  type      = string
  sensitive = true
}

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
