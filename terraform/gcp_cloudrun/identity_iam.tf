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

resource "google_service_account" "futu_opend" {
  account_id   = "${var.service_name}-futu-opend-sa"
  display_name = "Futu OpenD VM runtime"

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_iam_member" "futu_opend_rsa_key" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.futu_rsa_private_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.futu_opend.email}"
}
