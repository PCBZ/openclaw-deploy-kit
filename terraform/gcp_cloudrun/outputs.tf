output "cloud_run_service_name" {
  description = "Cloud Run service name"
  value       = google_cloud_run_v2_service.openclaw.name
}

output "cloud_run_url" {
  description = "Cloud Run service URL"
  value       = google_cloud_run_v2_service.openclaw.uri
}

output "runtime_service_account" {
  description = "Runtime service account email"
  value       = google_service_account.cloudrun.email
}
