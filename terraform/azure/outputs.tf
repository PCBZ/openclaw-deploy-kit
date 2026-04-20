# ── Outputs ──────────────────────────────────────────────────

output "public_ip" {
  description = "Public IP address of the container group"
  value       = azurerm_container_group.openclaw.ip_address
}

output "fqdn" {
  description = "Fully Qualified Domain Name for public access"
  value       = azurerm_container_group.openclaw.fqdn
}

output "gateway_url" {
  description = "OpenClaw Gateway URL"
  value       = "http://${azurerm_container_group.openclaw.fqdn}:18789"
}

output "container_group_id" {
  description = "Azure Container Group Resource ID"
  value       = azurerm_container_group.openclaw.id
}

output "resource_group_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.openclaw.name
}

# ── Storage Information ──────────────────────────────────

output "storage_account_name" {
  description = "Storage Account name"
  value       = azurerm_storage_account.openclaw.name
}

output "storage_account_id" {
  description = "Storage Account ID"
  value       = azurerm_storage_account.openclaw.id
}

output "storage_share_name" {
  description = "File Share name for persistent data"
  value       = azurerm_storage_share.openclaw.name
}

output "storage_share_url" {
  description = "File Share URL"
  value       = "https://${azurerm_storage_account.openclaw.name}.file.core.windows.net/${azurerm_storage_share.openclaw.name}"
}

# ── Function App Information ─────────────────────────────

output "function_app_name" {
  description = "Function App name"
  value       = azurerm_linux_function_app.openclaw.name
}

output "function_app_default_hostname" {
  description = "Function App default hostname"
  value       = azurerm_linux_function_app.openclaw.default_hostname
}

output "function_app_id" {
  description = "Function App resource ID"
  value       = azurerm_linux_function_app.openclaw.id
}

output "function_app_principal_id" {
  description = "Function App managed identity principal ID"
  value       = azurerm_linux_function_app.openclaw.identity[0].principal_id
}

output "app_service_plan_id" {
  description = "App Service Plan ID"
  value       = azurerm_service_plan.openclaw.id
}
