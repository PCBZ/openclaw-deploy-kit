output "app_url" {
  value = digitalocean_app.openclaw.live_url
}

output "registry_endpoint" {
  description = "Push your Docker image here"
  value       = "${digitalocean_container_registry.openclaw.server_url}/${digitalocean_container_registry.openclaw.name}/openclaw-telegram:latest"
}
