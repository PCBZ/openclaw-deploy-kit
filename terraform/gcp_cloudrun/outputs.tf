output "cloud_run_service_name" {
  description = "Cloud Run service name"
  value       = google_cloud_run_v2_service.openclaw.name
}

output "cloud_run_url" {
  description = "Cloud Run service URL"
  value       = google_cloud_run_v2_service.openclaw.uri
}

output "state_bucket_name" {
  description = "Persistent OpenClaw state bucket"
  value       = google_storage_bucket.state.name
}

output "runtime_service_account" {
  description = "Runtime service account email"
  value       = google_service_account.cloudrun.email
}
