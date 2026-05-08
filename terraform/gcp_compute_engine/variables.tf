variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region (e.g. us-west1)"
  type        = string
  default     = "us-west1"
}

variable "zone" {
  description = "GCP zone (e.g. us-west1-b)"
  type        = string
  default     = "us-west1-b"
}

variable "gcp_credentials_json" {
  description = "Optional service account JSON content. Leave empty to use ADC."
  type        = string
  sensitive   = true
  default     = ""
}

variable "vm_name" {
  description = "VM instance name"
  type        = string
  default     = "openclaw-e2-micro"
}

variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "e2-micro"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 30
}

variable "admin_username" {
  description = "Linux user for SSH"
  type        = string
  default     = "openclaw"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key (~/.ssh/id_rsa.pub)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "network_name" {
  description = "VPC network name (default uses pre-created network)"
  type        = string
  default     = "default"
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed SSH access (port 22)"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "gateway_allowed_cidrs" {
  description = "CIDR blocks allowed OpenClaw gateway access (port 18789)"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "swap_size" {
  description = "Swap file size in GB"
  type        = number
  default     = 3
}

variable "openclaw_memory_limit_mb" {
  description = "Hard memory limit for OpenClaw systemd service (MB)"
  type        = number
  default     = 800
}

variable "telegram_owner_id" {
  description = "Telegram numeric user ID for privileged commands e.g. /model (optional)"
  type        = string
  default     = ""
}

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
  description = "Brave Search API key (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_app_token" {
  description = "Slack App-Level Token (xapp-...)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_bot_token" {
  description = "Slack Bot OAuth Token (xoxb-...)"
  type        = string
  sensitive   = true
  default     = ""
}

# ── QQ Bot (optional) ─────────────────────────────────────────
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

# ── Cloudflare R2 (optional persistent memory) ──────────────
variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (for R2 persistence). Leave empty to disable R2."
  type        = string
  default     = ""
}

variable "r2_access_key_id" {
  description = "R2 S3-compatible Access Key ID. Leave empty to disable R2."
  type        = string
  sensitive   = true
  default     = ""
}

variable "r2_secret_access_key" {
  description = "R2 S3-compatible Secret Access Key. Leave empty to disable R2."
  type        = string
  sensitive   = true
  default     = ""
}

variable "r2_bucket_name" {
  description = "R2 bucket name for OpenClaw state persistence. Leave empty to disable R2."
  type        = string
  default     = ""
}
