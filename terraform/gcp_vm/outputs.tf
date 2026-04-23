output "vm_public_ip" {
  description = "Public IP address of the VM (use this for SSH)"
  value       = google_compute_instance.main.network_interface[0].access_config[0].nat_ip
}

output "vm_name" {
  description = "Name of the VM"
  value       = google_compute_instance.main.name
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ${var.admin_username}@${google_compute_instance.main.network_interface[0].access_config[0].nat_ip}"
}

output "openclaw_gateway_url" {
  description = "OpenClaw gateway health check URL (after bootstrap completes)"
  value       = "http://${google_compute_instance.main.network_interface[0].access_config[0].nat_ip}:18789/health"
}
