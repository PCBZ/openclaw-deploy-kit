resource "cloudflare_r2_bucket" "state" {
  account_id = var.cloudflare_account_id
  name       = var.r2_bucket_name
}

# Write openclaw.json to a local temp file (sensitive: content won't appear in
# Terraform plan/apply output or process listings).
resource "local_sensitive_file" "openclaw_json" {
  content  = local.openclaw_json_content
  filename = "${path.module}/.terraform/tmp/openclaw.json"
}

# Upload openclaw.json to R2 via aws CLI (S3-compatible endpoint).
# Reads from the temp file — no secrets are passed as command-line arguments.
# Requires: awscli installed locally.
# rclone-sync sidecar restores it into the container on each startup.
resource "null_resource" "openclaw_json_r2" {
  triggers = {
    content_hash = md5(local.openclaw_json_content)
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws s3 cp "${local_sensitive_file.openclaw_json.filename}" \
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

  depends_on = [cloudflare_r2_bucket.state, local_sensitive_file.openclaw_json]
}
