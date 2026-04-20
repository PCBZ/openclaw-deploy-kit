terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

# ── Resource Group ───────────────────────────────────────────

resource "azurerm_resource_group" "openclaw" {
  name     = var.resource_group_name
  location = var.location
}

# ── Storage Account (for persistent data) ────────────────────

resource "azurerm_storage_account" "openclaw" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.openclaw.name
  location                 = azurerm_resource_group.openclaw.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "production"
    app         = "openclaw"
  }
}

# ── File Share (for OpenClaw data persistence) ───────────────

resource "azurerm_storage_share" "openclaw" {
  name                 = var.storage_share_name
  storage_account_name = azurerm_storage_account.openclaw.name
  quota                = 10  # 10 GB quota for OpenClaw data

  depends_on = [azurerm_storage_account.openclaw]
}

# ── Generate and Upload OpenClaw Configuration ──────────────
# Create openclaw.json with Telegram and Slack configuration

locals {
  openclaw_config = templatefile("${path.module}/openclaw.json.tpl", {
    openclaw_gateway_token = var.openclaw_gateway_token
    openrouter_api_key     = var.openrouter_api_key
    telegram_bot_token     = var.telegram_bot_token
    telegram_owner_id      = var.telegram_owner_id
    slack_app_token        = try(var.slack_app_token, "")
    slack_bot_token        = try(var.slack_bot_token, "")
    brave_api_key          = var.brave_api_key
  })
}

# Write config locally for verification
resource "local_file" "openclaw_config" {
  content  = local.openclaw_config
  filename = "${path.module}/.openclaw.json"
}

# Auto-upload config to File Share using Azure CLI
resource "null_resource" "upload_openclaw_config" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      ACCOUNT_NAME="${azurerm_storage_account.openclaw.name}"
      SHARE_NAME="${azurerm_storage_share.openclaw.name}"
      RESOURCE_GROUP="${azurerm_resource_group.openclaw.name}"
      CONFIG_FILE="${local_file.openclaw_config.filename}"
      
      # Get storage account key
      STORAGE_KEY=$(az storage account keys list \
        --account-name "$ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "[0].value" -o tsv)
      
      # Upload config file
      az storage file upload \
        --account-name "$ACCOUNT_NAME" \
        --account-key "$STORAGE_KEY" \
        --share-name "$SHARE_NAME" \
        --source "$CONFIG_FILE" \
        --path "openclaw.json" \
        --output none
      
      echo "✅ openclaw.json uploaded successfully"
    EOT
  }

  depends_on = [
    azurerm_storage_share.openclaw,
    local_file.openclaw_config
  ]
}

# ── Container Group ──────────────────────────────────────────

resource "azurerm_container_group" "openclaw" {
  name                = var.container_group_name
  location            = azurerm_resource_group.openclaw.location
  resource_group_name = azurerm_resource_group.openclaw.name
  os_type             = "Linux"
  ip_address_type     = "Public"
  restart_policy      = "OnFailure"

  container {
    name   = "openclaw"
    image  = var.container_image
    cpu    = var.cpu_cores
    memory = var.memory_gb

    # Environment variables
    environment_variables = {
      OPENROUTER_API_KEY     = try(var.openrouter_api_key, "")
      OPENCLAW_GATEWAY_TOKEN = try(var.openclaw_gateway_token, "")
      BRAVE_API_KEY          = try(var.brave_api_key, "")
      OPENCLAW_ONBOARD_NON_INTERACTIVE = "1"
    }

    # Expose Gateway port
    ports {
      port     = 18789
      protocol = "TCP"
    }

    # Mount Azure File Share for persistent storage
    volume {
      name                 = "openclaw-storage"
      mount_path           = "/root/.openclaw"
      storage_account_name = azurerm_storage_account.openclaw.name
      storage_account_key  = azurerm_storage_account.openclaw.primary_access_key
      share_name           = azurerm_storage_share.openclaw.name
    }
  }

  # Exposed ports for external access
  exposed_port {
    port     = 18789
    protocol = "TCP"
  }

  # DNS label for public access
  dns_name_label = var.dns_name_label

  tags = {
    environment = "production"
    app         = "openclaw"
  }

  depends_on = [
    azurerm_storage_share.openclaw,
    null_resource.upload_openclaw_config
  ]
}

# ── Network Security Group ───────────────────────────────────

resource "azurerm_network_security_group" "openclaw" {
  name                = "${var.container_group_name}-nsg"
  location            = azurerm_resource_group.openclaw.location
  resource_group_name = azurerm_resource_group.openclaw.name

  security_rule {
    name                       = "AllowGateway"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "18789"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "production"
    app         = "openclaw"
  }
}

# ── Storage Account for Function App Runtime ────────────────

resource "azurerm_storage_account" "function" {
  name                     = var.function_storage_account_name
  resource_group_name      = azurerm_resource_group.openclaw.name
  location                 = azurerm_resource_group.openclaw.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "production"
    app         = "openclaw-functions"
  }
}

# ── App Service Plan for Function App ────────────────────────

resource "azurerm_service_plan" "openclaw" {
  name                = var.app_service_plan_name
  location            = azurerm_resource_group.openclaw.location
  resource_group_name = azurerm_resource_group.openclaw.name
  os_type             = "Linux"
  sku_name            = "Y1"  # Consumption plan (pay-per-execution)

  tags = {
    environment = "production"
    app         = "openclaw-functions"
  }
}

# ── Function App ─────────────────────────────────────────────

resource "azurerm_linux_function_app" "openclaw" {
  name                = var.function_app_name
  location            = azurerm_resource_group.openclaw.location
  resource_group_name = azurerm_resource_group.openclaw.name
  service_plan_id     = azurerm_service_plan.openclaw.id

  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key

  # Python runtime
  site_config {
    application_stack {
      python_version = "3.10"
    }
    
    # Increase timeout for ECI startup
    http2_enabled                 = true
    app_scale_limit               = 200
    elastic_instance_minimum      = 0
  }

  # Application settings
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"             = "python"
    "FUNCTIONS_EXTENSION_VERSION"          = "~4"
    "PYTHON_VERSION"                       = "3.10"
    
    # Openclaw-specific settings
    "ACI_RESOURCE_GROUP"                   = azurerm_resource_group.openclaw.name
    "ACI_CONTAINER_GROUP_NAME"             = azurerm_container_group.openclaw.name
    "ACI_ID"                               = azurerm_container_group.openclaw.id
    "OPENCLAW_GATEWAY_IP"                  = azurerm_container_group.openclaw.ip_address
    "OPENCLAW_GATEWAY_PORT"                = "18789"
    
    # Auto-stop configuration
    "IDLE_TIMEOUT_MINUTES"                 = tostring(var.idle_timeout_minutes)
    
    # Azure credentials for ACI management
    "AZURE_SUBSCRIPTION_ID"                = var.subscription_id
    "AZURE_TENANT_ID"                      = var.tenant_id
    "AZURE_CLIENT_ID"                      = var.client_id
    "AZURE_CLIENT_SECRET"                  = var.client_secret
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [azurerm_storage_account.function]

  tags = {
    environment = "production"
    app         = "openclaw-functions"
  }
}

# ── Role Assignment for Function App to manage ACI ──────────
# NOTE: Azure Student accounts may not have permission to create role assignments
# If Terraform apply fails with authorization error, manually assign in Azure Portal:
# 1. Go to Function App → Settings → Identity → copy Object ID
# 2. Go to Resource Group → Access Control (IAM) → Add → Contributor role
# 3. Paste the Object ID and save

# resource "azurerm_role_assignment" "function_aci_management" {
#   scope              = azurerm_resource_group.openclaw.id
#   role_definition_name = "Contributor"
#   principal_id       = azurerm_linux_function_app.openclaw.identity[0].principal_id
# }

# ── Auto-deploy Function Code ────────────────────────────────
# Automatically publishes Python functions to Azure after infrastructure is created
# Note: Ignores trigger sync errors which are non-critical

resource "null_resource" "deploy_function" {
  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/function
      OUTPUT=$(func azure functionapp publish ${azurerm_linux_function_app.openclaw.name} 2>&1 || true)
      echo "$OUTPUT"
      
      # Check if deployment succeeded despite trigger sync error
      if echo "$OUTPUT" | grep -q "Remote build succeeded"; then
        exit 0
      else
        exit 1
      fi
    EOT
  }

  depends_on = [
    azurerm_linux_function_app.openclaw
  ]
}

# Verify config was uploaded
resource "null_resource" "verify_config_upload" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Verifying openclaw.json was uploaded to File Share..."
      STORAGE_KEY=$(az storage account keys list \
        --account-name ${azurerm_storage_account.openclaw.name} \
        --resource-group ${azurerm_resource_group.openclaw.name} \
        --query "[0].value" -o tsv)
      
      FILE_EXISTS=$(az storage file exists \
        --account-name ${azurerm_storage_account.openclaw.name} \
        --account-key "$STORAGE_KEY" \
        --share-name ${azurerm_storage_share.openclaw.name} \
        --path "openclaw.json" \
        --query "exists" -o tsv)
      
      if [ "$FILE_EXISTS" = "true" ]; then
        echo "✅ openclaw.json verified in File Share"
      else
        echo "❌ ERROR: openclaw.json not found in File Share"
        exit 1
      fi
    EOT
  }

  depends_on = [
    null_resource.upload_openclaw_config
  ]
}
