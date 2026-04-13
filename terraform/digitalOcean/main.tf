terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# ── SSH Key ──────────────────────────────────────────────────

resource "digitalocean_ssh_key" "openclaw" {
  count      = var.existing_ssh_key_fingerprint == "" ? 1 : 0
  name       = "openclaw-key"
  public_key = file(var.ssh_public_key_path)
}

locals {
  openclaw_ssh_key_fingerprint = var.existing_ssh_key_fingerprint != "" ? var.existing_ssh_key_fingerprint : digitalocean_ssh_key.openclaw[0].fingerprint

  # Build plugin paths based on enabled channels
  plugin_paths = join(
    ",\n        ",
    concat(
      ["\"/usr/lib/node_modules/openclaw/dist/extensions/telegram\""],
      var.line_channel_access_token != "" && var.line_channel_secret != "" ? ["\"/usr/lib/node_modules/openclaw/dist/extensions/line\""] : []
    )
  )

  # Build plugin entries based on enabled channels
  plugin_entries = join(
    "\n      ",
    concat(
      ["\"telegram\": { \"enabled\": true },"],
      var.line_channel_access_token != "" && var.line_channel_secret != "" ? ["\"line\": { \"enabled\": true },"] : []
    )
  )

  # Build LINE channel JSON section (empty if not configured)
  line_channel_json = var.line_channel_access_token != "" && var.line_channel_secret != "" ? ",\n    \"line\": {\n      \"enabled\": true,\n      \"accounts\": {\n        \"default\": {\n          \"channelAccessToken\": \"${var.line_channel_access_token}\",\n          \"channelSecret\": \"${var.line_channel_secret}\"\n        }\n      }\n    }" : ""
}

# ── Firewall ─────────────────────────────────────────────────

resource "digitalocean_firewall" "openclaw" {
  name        = "openclaw-firewall"
  droplet_ids = [digitalocean_droplet.openclaw.id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.ssh_allowed_cidrs
  }

  # OpenClaw gateway
  inbound_rule {
    protocol         = "tcp"
    port_range       = "18789"
    source_addresses = var.gateway_allowed_cidrs
  }


  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# ── Droplet ──────────────────────────────────────────────────

resource "digitalocean_droplet" "openclaw" {
  name     = "openclaw-host"
  region   = var.region
  size     = var.droplet_size
  image    = "ubuntu-24-04-x64"
  ssh_keys = [local.openclaw_ssh_key_fingerprint]

  user_data = templatefile("${path.module}/bootstrap.sh", {
    openrouter_api_key        = var.openrouter_api_key
    telegram_bot_token        = var.telegram_bot_token
    line_channel_access_token = var.line_channel_access_token
    line_channel_secret       = var.line_channel_secret
    openclaw_gateway_token    = var.openclaw_gateway_token
    brave_api_key             = var.brave_api_key
    swap_size                 = var.swap_size
    telegram_owner_id         = var.telegram_owner_id
    plugin_paths              = local.plugin_paths
    plugin_entries            = local.plugin_entries
    line_channel_json         = local.line_channel_json
  })
}

# ── Outputs ──────────────────────────────────────────────────

output "public_ip" {
  value = digitalocean_droplet.openclaw.ipv4_address
}

output "ssh_command" {
  value = "ssh root@${digitalocean_droplet.openclaw.ipv4_address}"
}