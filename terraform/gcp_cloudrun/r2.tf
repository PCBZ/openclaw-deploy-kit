# R2 bucket is managed in terraform/shared/ (independent state).
# Cloud Run only uploads openclaw.json to the existing bucket.

resource "local_sensitive_file" "openclaw_json" {
  content  = local.openclaw_json_content
  filename = "${path.module}/.terraform/tmp/openclaw.json"
}

resource "null_resource" "openclaw_json_r2" {
  triggers = {
    content_hash = md5(local.openclaw_json_content)
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws s3 cp "${local_sensitive_file.openclaw_json.filename}" \
        "s3://${var.r2_bucket_name}/openclaw.json" \
        --endpoint-url "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com" \
        --content-type "application/json"
    EOT
    environment = {
      AWS_ACCESS_KEY_ID     = var.r2_access_key_id
      AWS_SECRET_ACCESS_KEY = var.r2_secret_access_key
      AWS_DEFAULT_REGION    = "auto"
    }
  }

  depends_on = [local_sensitive_file.openclaw_json]
}
