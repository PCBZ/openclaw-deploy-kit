# ── Azure Authentication ────────────────────────────────────
# These come from terraform.tfvars
variable "subscription_id" {
  sensitive = true
}

variable "client_id" {
  sensitive = true
}

variable "client_secret" {
  sensitive = true
}

variable "tenant_id" {
  sensitive = true
}

# ── Azure Resource Group ────────────────────────────────────
variable "resource_group_name" {
  description = "Azure resource group name (must already exist)"
  type        = string
}

variable "location" {
  description = "Azure region (e.g., eastus, canadaeast, westus)"
  type        = string
}

# ── VM Configuration ────────────────────────────────────────
variable "vm_name" {
  description = "Name of the VM"
  type        = string
  default     = "openclaw-b2pts"
}

variable "vm_size" {
  description = "Azure VM SKU"
  type        = string
  default     = "Standard_B2pts_v2"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 30
}

# ── VM OS Configuration ────────────────────────────────────
variable "admin_username" {
  description = "VM admin username"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key (~/.ssh/id_rsa.pub)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# ── Network Security Group (NSG) ────────────────────────────
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

# ── Static Public IP ────────────────────────────────────────
variable "public_ip_name" {
  description = "Name of static public IP"
  type        = string
  default     = "openclaw-b2pts-public-ip"
}

# ── OpenClaw Configuration ─────────────────────────────────
variable "swap_size" {
  description = "Swap file size in GB"
  type        = number
  default     = 2
}

variable "openclaw_memory_limit_mb" {
  description = "Hard memory limit for OpenClaw systemd service (MB)"
  type        = number
  default     = 800
}

# ── Secrets (from .env via .envrc) ─────────────────────────
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
