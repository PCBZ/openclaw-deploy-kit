resource "google_service_account" "cloudrun" {
  account_id   = "${var.service_name}-run-sa"
  display_name = "OpenClaw Cloud Run runtime"

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}
