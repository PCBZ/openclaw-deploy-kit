locals {
  ssh_rule_defs = {
    for idx, cidr in var.ssh_allowed_cidrs : "ssh-${idx}" => {
      name        = "AllowSSH_${idx}"
      priority    = 100 + idx
      port        = "22"
      source_cidr = cidr
      dest_prefix = length(regexall(":", cidr)) > 0 ? "::/0" : "*"
    }
  }

  gateway_rule_defs = {
    for idx, cidr in var.gateway_allowed_cidrs : "gateway-${idx}" => {
      name        = "AllowOpenClawGateway_${idx}"
      priority    = 200 + idx
      port        = "18789"
      source_cidr = cidr
      dest_prefix = length(regexall(":", cidr)) > 0 ? "::/0" : "*"
    }
  }

  inbound_allow_rules = merge(local.ssh_rule_defs, local.gateway_rule_defs)
}

resource "azurerm_network_security_group" "main" {
  name                = "${var.vm_name}-nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_network_security_rule" "inbound_allow" {
  for_each = local.inbound_allow_rules

  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value.port
  source_address_prefix       = each.value.source_cidr
  destination_address_prefix  = each.value.dest_prefix
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_security_rule" "allow_all_outbound" {
  name                        = "AllowAllOutbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}
