variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (visible on Dashboard sidebar)"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token with R2:Edit permission"
  type        = string
  sensitive   = true
}

variable "r2_bucket_name" {
  description = "R2 bucket name shared between Cloud Run and Compute Engine"
  type        = string
  default     = "openclaw-state"
}
