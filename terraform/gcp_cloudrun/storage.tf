resource "google_storage_bucket" "state" {
  name                        = var.bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  depends_on = [google_project_service.required]
}

resource "google_storage_bucket_object" "openclaw_json" {
  name    = "openclaw.json"
  bucket  = google_storage_bucket.state.name
  content = local.openclaw_json_content
}

resource "google_storage_bucket_object" "workspace_keep" {
  name    = "workspace/.keep"
  bucket  = google_storage_bucket.state.name
  content = "keep"
}
