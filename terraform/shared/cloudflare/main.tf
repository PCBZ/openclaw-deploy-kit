resource "cloudflare_r2_bucket" "state" {
  account_id = var.cloudflare_account_id
  name       = var.r2_bucket_name
}
