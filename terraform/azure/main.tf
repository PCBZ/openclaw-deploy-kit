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

# ── Container Group (initially stopped) ───────────────────────
# This container will be started by Azure Function on webhook trigger

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
    # API Keys are loaded from .env file via TF_VAR_ environment variables
    # Before running terraform: source .env or use direnv with .envrc
    environment_variables = {
      OPENROUTER_API_KEY     = try(var.openrouter_api_key, "")
      TELEGRAM_BOT_TOKEN     = try(var.telegram_bot_token, "")
      OPENCLAW_GATEWAY_TOKEN = try(var.openclaw_gateway_token, "")
      BRAVE_API_KEY          = try(var.brave_api_key, "")
      TELEGRAM_OWNER_ID      = try(var.telegram_owner_id, "")
      SLACK_APP_TOKEN        = try(var.slack_app_token, "")
      SLACK_BOT_TOKEN        = try(var.slack_bot_token, "")
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
  exposed_ports {
    port     = 18789
    protocol = "TCP"
  }

  # DNS label for public access
  dns_name_label = var.dns_name_label

  tags = {
    environment = "production"
    app         = "openclaw"
  }

  depends_on = [azurerm_storage_share.openclaw]
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
    
    # For function timeout
    function_app_scale_limit      = 200
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

resource "azurerm_role_assignment" "function_aci_management" {
  scope              = azurerm_resource_group.openclaw.id
  role_definition_name = "Contributor"
  principal_id       = azurerm_linux_function_app.openclaw.identity[0].principal_id
}

# ── Auto-deploy Function Code ────────────────────────────────
# Automatically publishes Python functions to Azure after infrastructure is created

resource "null_resource" "deploy_function" {
  provisioner "local-exec" {
    command = "cd ${path.module}/function && func azure functionapp publish ${azurerm_linux_function_app.openclaw.name}"
  }

  depends_on = [
    azurerm_linux_function_app.openclaw,
    azurerm_role_assignment.function_aci_management
  ]
}
