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
  name       = "openclaw-key"
  public_key = file(var.ssh_public_key_path)
}

# ── Firewall ─────────────────────────────────────────────────

resource "digitalocean_firewall" "openclaw" {
  name        = "openclaw-firewall"
  droplet_ids = [digitalocean_droplet.openclaw.id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # OpenClaw gateway
  inbound_rule {
    protocol         = "tcp"
    port_range       = "18789"
    source_addresses = ["0.0.0.0/0", "::/0"]
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
  ssh_keys = [digitalocean_ssh_key.openclaw.fingerprint]

  user_data = templatefile("${path.module}/bootstrap.sh", {
    openrouter_api_key     = var.openrouter_api_key
    telegram_bot_token     = var.telegram_bot_token
    openclaw_gateway_token = var.openclaw_gateway_token
    brave_api_key          = var.brave_api_key
    swap_size              = var.swap_size
    telegram_owner_id      = var.telegram_owner_id
  })
}

# ── Outputs ──────────────────────────────────────────────────

output "public_ip" {
  value = digitalocean_droplet.openclaw.ipv4_address
}

output "ssh_command" {
  value = "ssh root@${digitalocean_droplet.openclaw.ipv4_address}"
}