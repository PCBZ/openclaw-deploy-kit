output "vm_public_ip" {
  description = "Public IP address of the B1s VM (use this for SSH)"
  value       = azurerm_public_ip.main.ip_address
}

output "vm_name" {
  description = "Name of the B1s VM"
  value       = azurerm_linux_virtual_machine.main.name
}

output "vm_private_ip" {
  description = "Private IP address of the B1s VM"
  value       = azurerm_network_interface.main.private_ip_address
}

output "ssh_command" {
  description = "SSH command to connect to the B1s VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
}

output "openclaw_gateway_url" {
  description = "OpenClaw gateway health check URL (after bootstrap completes)"
  value       = "http://${azurerm_public_ip.main.ip_address}:18789/health"
}
