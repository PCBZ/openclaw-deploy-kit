# ── Resource Group (must already exist) ──────────────────────
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# ── Virtual Network and Subnet ───────────────────────────────
resource "azurerm_virtual_network" "main" {
  name                = "${var.vm_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_subnet" "internal" {
  name                 = "${var.vm_name}-subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# ── Network Interface (NIC) ──────────────────────────────────
resource "azurerm_network_interface" "main" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

# ── Static Public IP ─────────────────────────────────────────
resource "azurerm_public_ip" "main" {
  name                = var.public_ip_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ── Network Security Group (NSG) ────────────────────────────
resource "azurerm_network_security_group" "main" {
  name                = "${var.vm_name}-nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  # SSH access (port 22) - IPv4
  security_rule {
    name                       = "AllowSSH_IPv4"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }

  # SSH access (port 22) - IPv6
  security_rule {
    name                       = "AllowSSH_IPv6"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "::/0"
    destination_address_prefix = "::/0"
  }

  # OpenClaw Gateway access (port 18789) - IPv4
  security_rule {
    name                       = "AllowOpenClawGateway_IPv4"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "18789"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }

  # OpenClaw Gateway access (port 18789) - IPv6
  security_rule {
    name                       = "AllowOpenClawGateway_IPv6"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "18789"
    source_address_prefix      = "::/0"
    destination_address_prefix = "::/0"
  }

  # Deny all other inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow all outbound
  security_rule {
    name                       = "AllowAllOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ── Associate NSG with NIC ───────────────────────────────────
resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# ── B1s Virtual Machine ──────────────────────────────────────
resource "azurerm_linux_virtual_machine" "main" {
  name                = var.vm_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  size                = var.vm_size

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-arm64"
    version   = "latest"
  }

  # Temp disk is automatically allocated for B1s (4GB at /mnt/resource)
  # No explicit configuration needed, but ensure it's not disabled by default

  custom_data = base64encode(templatefile("${path.module}/bootstrap.sh", {
    openrouter_api_key       = var.openrouter_api_key
    telegram_bot_token       = var.telegram_bot_token
    openclaw_gateway_token   = var.openclaw_gateway_token
    brave_api_key            = var.brave_api_key
    swap_size                = var.swap_size
    openclaw_memory_limit_mb = var.openclaw_memory_limit_mb
    openclaw_json_content    = templatefile("${path.module}/openclaw.json.tpl", {
      openclaw_gateway_token = var.openclaw_gateway_token
      openrouter_api_key     = var.openrouter_api_key
      brave_api_key          = var.brave_api_key
      telegram_bot_token     = var.telegram_bot_token
      slack_app_token        = var.slack_app_token
      slack_bot_token        = var.slack_bot_token
      slack_enabled          = var.slack_app_token != "" && var.slack_bot_token != ""
    })
  }))

  tags = {
    Environment = "Production"
    Application = "OpenClaw"
  }
}
