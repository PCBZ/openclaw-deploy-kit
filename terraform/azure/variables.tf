# ── Azure Auth ──────────────────────────────────────────────
variable "subscription_id" {
  description = "Azure Subscription ID"
  sensitive   = true
}

variable "client_id" {
  description = "Azure Service Principal Client ID"
  sensitive   = true
}

variable "client_secret" {
  description = "Azure Service Principal Client Secret"
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  sensitive   = true
}

# ── Resource Group & Location ───────────────────────────────
variable "resource_group_name" {
  description = "Azure Resource Group name"
  default     = "openclaw-rg"
}

variable "location" {
  description = "Azure region (e.g. eastus, westus, canadaeast)"
  default     = "eastus"
}

# ── Storage Account ──────────────────────────────────────────
variable "storage_account_name" {
  description = "Azure Storage Account name (must be globally unique, lowercase alphanumeric)"
  default     = "openclawstorage"
}

variable "storage_share_name" {
  description = "Azure File Share name"
  default     = "openclaw-data"
}

# ── Function App Configuration ───────────────────────────────

variable "function_storage_account_name" {
  description = "Azure Storage Account name for Function App runtime (must be globally unique)"
  default     = "openclawfunctionstg"
}

variable "app_service_plan_name" {
  description = "App Service Plan name for Function App"
  default     = "openclaw-asp"
}

variable "function_app_name" {
  description = "Azure Function App name (must be globally unique)"
  default     = "openclaw-function-app"
}

# ── Auto-Stop Configuration ──────────────────────────────────

variable "idle_timeout_minutes" {
  description = "Minutes of inactivity before auto-stopping ACI"
  default     = 30
  type        = number
}

# ── Container Group ─────────────────────────────────────────
variable "container_group_name" {
  description = "Azure Container Group name"
  default     = "openclaw-container"
}

variable "container_image" {
  description = "Docker container image (e.g. myregistry.azurecr.io/openclaw:latest or docker.io/library/ubuntu:latest)"
  default     = "docker.io/library/ubuntu:24.04"
}

variable "dns_name_label" {
  description = "DNS name label for public access (must be globally unique)"
  default     = "openclaw-aci"
}

variable "cpu_cores" {
  description = "Number of CPU cores (0.5, 1, 1.5, 2, etc.)"
  default     = 1
  type        = number
}

variable "memory_gb" {
  description = "Memory in GB (must be between 0.5 and 64, paired with CPU)"
  default     = 1
  type        = number
}

# ── Secrets ──────────────────────────────────────────────────
# These are injected from .env file via TF_VAR_ environment variables
# See .envrc for how they are loaded with direnv
# Or manually: export TF_VAR_openrouter_api_key=$OPENROUTER_API_KEY before terraform apply

variable "openrouter_api_key" {
  description = "OpenRouter API key (from .env)"
  sensitive   = true
  default     = ""
  type        = string
}

variable "telegram_bot_token" {
  description = "Telegram Bot Token (from .env)"
  sensitive   = true
  default     = ""
  type        = string
}

variable "openclaw_gateway_token" {
  description = "OpenClaw Gateway Token (from .env)"
  sensitive   = true
  default     = ""
  type        = string
}

variable "brave_api_key" {
  description = "Brave Search API key (from .env)"
  sensitive   = true
  default     = ""
  type        = string
}

variable "telegram_owner_id" {
  description = "Your Telegram numeric user ID (from .env)"
  default     = ""
  type        = string
}

variable "slack_app_token" {
  description = "Slack App-Level Token (from .env)"
  sensitive   = true
  default     = ""
  type        = string
}

variable "slack_bot_token" {
  description = "Slack Bot User OAuth Token (from .env)"
  sensitive   = true
  default     = ""
  type        = string
}
