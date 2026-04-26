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

variable "container_image" {
  description = "Container image override. Leave empty to use GHCR proxy image via Artifact Registry remote repository."
  type        = string
  default     = ""
}

variable "enable_ghcr_proxy" {
  description = "Create an Artifact Registry remote repository that proxies ghcr.io and use it as Cloud Run image source."
  type        = bool
  default     = true
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

variable "bucket_name" {
  description = "GCS bucket name for persistent OpenClaw state"
  type        = string
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
  sensitive = true
}

variable "telegram_bot_token" {
  sensitive = true
}

variable "openclaw_gateway_token" {
  sensitive = true
}

variable "brave_api_key" {
  description = "Brave Search API key (optional)"
  sensitive   = true
  default     = ""
}

variable "telegram_owner_id" {
  description = "Telegram numeric user ID for privileged commands"
  default     = ""
}

variable "slack_app_token" {
  description = "Slack App-Level Token (xapp-...)"
  sensitive   = true
  default     = ""
}

variable "slack_bot_token" {
  description = "Slack Bot OAuth Token (xoxb-...)"
  sensitive   = true
  default     = ""
}
