resource "cloudflare_r2_bucket" "state" {
  account_id = var.cloudflare_account_id
  name       = var.r2_bucket_name
}

# Upload openclaw.json to R2 via aws CLI (S3-compatible endpoint).
# Requires: awscli installed locally.
# rclone-sync sidecar restores it into the container on each startup.
resource "null_resource" "openclaw_json_r2" {
  triggers = {
    content_hash = md5(local.openclaw_json_content)
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo '${replace(local.openclaw_json_content, "'", "'\\''")}' | \
      aws s3 cp - \
        "s3://${cloudflare_r2_bucket.state.name}/openclaw.json" \
        --endpoint-url "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com" \
        --content-type "application/json"
    EOT
    environment = {
      AWS_ACCESS_KEY_ID     = var.r2_access_key_id
      AWS_SECRET_ACCESS_KEY = var.r2_secret_access_key
      AWS_DEFAULT_REGION    = "auto"
    }
  }

  depends_on = [cloudflare_r2_bucket.state]
}
