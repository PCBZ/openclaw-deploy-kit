# ── OCI Auth ────────────────────────────────────────────────
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {
  default = "us-ashburn-1"
}

# ── OCI Resource ────────────────────────────────────────────
variable "compartment_id" {}
variable "availability_domain" {
  description = "e.g. Uocm:US-ASHBURN-AD-1"
}

# ── Secrets（Read from .env）────────────────────────────
variable "openrouter_api_key" {
  sensitive = true
}
variable "telegram_bot_token" {
  sensitive = true
}
variable "openclaw_gateway_token" {
  sensitive = true
}