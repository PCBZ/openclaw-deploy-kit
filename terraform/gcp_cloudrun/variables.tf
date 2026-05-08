variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region (Cloud Run)"
  type        = string
  default     = "us-west1"
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "openclaw"
}

variable "ghcr_remote_repository_id" {
  description = "Artifact Registry repository_id for GHCR proxy."
  type        = string
  default     = "ghcr-remote"
}

variable "ghcr_remote_repository_description" {
  description = "Description for GHCR proxy remote repository."
  type        = string
  default     = "Proxy cache for ghcr.io images"
}

variable "ghcr_upstream_uri" {
  description = "Upstream URI for GHCR remote repository."
  type        = string
  default     = "https://ghcr.io"
}

variable "ghcr_image_path" {
  description = "Image path on GHCR to pull through the proxy."
  type        = string
  default     = "openclaw/openclaw"
}

variable "ghcr_image_tag" {
  description = "Image tag on GHCR to pull through the proxy."
  type        = string
  default     = "latest"
}

variable "gcp_credentials_json" {
  description = "Optional service account JSON content. Leave empty to use ADC."
  type        = string
  sensitive   = true
  default     = ""
}

variable "min_instances" {
  description = "Cloud Run minimum instances"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Cloud Run maximum instances"
  type        = number
  default     = 3
}

variable "openrouter_api_key" {
  type      = string
  sensitive = true
}

variable "telegram_bot_token" {
  type      = string
  sensitive = true
}

variable "telegram_owner_id" {
  description = "Telegram numeric user ID for owner-only DM access. Leave empty for open DMs."
  type        = string
  default     = ""
}

variable "openclaw_gateway_token" {
  type      = string
  sensitive = true
}

variable "brave_api_key" {
  description = "Brave Search API key (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_app_token" {
  description = "Slack App-Level Token (xapp-...)"
  type        = string
  sensitive   = true
}

variable "slack_bot_token" {
  description = "Slack Bot OAuth Token (xoxb-...)"
  type        = string
  sensitive   = true
}

# ── QQ Bot ────────────────────────────────────────────────────
variable "qq_app_id" {
  description = "QQ Bot App ID from QQ Open Platform (q.qq.com). Leave empty to disable QQ."
  type        = string
  sensitive   = true
  default     = ""
}

variable "qq_client_secret" {
  description = "QQ Bot Client Secret. Leave empty to disable QQ."
  type        = string
  sensitive   = true
  default     = ""
}

variable "qq_owner_id" {
  description = "QQ OpenID of bot owner for DM allowlist. Leave empty to allow all DMs."
  type        = string
  default     = ""
}

# ── Cloudflare R2 ─────────────────────────────────────────────
variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (visible on Dashboard sidebar)"
  type        = string
}

variable "r2_access_key_id" {
  description = "R2 S3-compatible Access Key ID (from R2 → Manage R2 API Tokens)"
  type        = string
  sensitive   = true
}

variable "r2_secret_access_key" {
  description = "R2 S3-compatible Secret Access Key"
  type        = string
  sensitive   = true
}

variable "r2_bucket_name" {
  description = "R2 bucket name for OpenClaw state persistence"
  type        = string
  default     = "openclaw-state"
}
