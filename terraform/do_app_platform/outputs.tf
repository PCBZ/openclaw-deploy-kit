output "app_url" {
  value = digitalocean_app.openclaw.live_url
}

output "app_id" {
  value       = digitalocean_app.openclaw.id
  description = "App ID — use with: doctl apps logs <app-id> --type=run"
}
