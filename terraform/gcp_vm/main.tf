locals {
  ssh_key_entry = "${var.admin_username}:${file(var.ssh_public_key_path)}"
  ssh_ipv4_cidrs = [
    for cidr in var.ssh_allowed_cidrs : cidr
    if length(regexall(":", cidr)) == 0
  ]
  ssh_ipv6_cidrs = [
    for cidr in var.ssh_allowed_cidrs : cidr
    if length(regexall(":", cidr)) > 0
  ]
  gateway_ipv4_cidrs = [
    for cidr in var.gateway_allowed_cidrs : cidr
    if length(regexall(":", cidr)) == 0
  ]
  gateway_ipv6_cidrs = [
    for cidr in var.gateway_allowed_cidrs : cidr
    if length(regexall(":", cidr)) > 0
  ]

  openclaw_json_content = templatefile("${path.module}/openclaw.json.tpl", {
    openclaw_gateway_token = var.openclaw_gateway_token
    openrouter_api_key     = var.openrouter_api_key
    brave_api_key          = var.brave_api_key
    telegram_bot_token     = var.telegram_bot_token
    slack_app_token        = var.slack_app_token
    slack_bot_token        = var.slack_bot_token
    slack_enabled          = var.slack_app_token != "" && var.slack_bot_token != ""
  })

  bootstrap_vars = {
    openrouter_api_key       = var.openrouter_api_key
    telegram_bot_token       = var.telegram_bot_token
    openclaw_gateway_token   = var.openclaw_gateway_token
    brave_api_key            = var.brave_api_key
    swap_size                = var.swap_size
    openclaw_memory_limit_mb = var.openclaw_memory_limit_mb
    approve_operator_script  = file("${path.module}/approve_operator_approvals.py")
    openclaw_json_content    = local.openclaw_json_content
  }
}

resource "google_compute_firewall" "allow_ssh_ipv4" {
  count   = length(local.ssh_ipv4_cidrs) > 0 ? 1 : 0
  name    = "${var.vm_name}-allow-ssh-ipv4"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = local.ssh_ipv4_cidrs
  target_tags   = [var.vm_name]
}

resource "google_compute_firewall" "allow_ssh_ipv6" {
  count   = length(local.ssh_ipv6_cidrs) > 0 ? 1 : 0
  name    = "${var.vm_name}-allow-ssh-ipv6"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = local.ssh_ipv6_cidrs
  target_tags   = [var.vm_name]
}

resource "google_compute_firewall" "allow_gateway_ipv4" {
  count   = length(local.gateway_ipv4_cidrs) > 0 ? 1 : 0
  name    = "${var.vm_name}-allow-gateway-ipv4"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["18789"]
  }

  source_ranges = local.gateway_ipv4_cidrs
  target_tags   = [var.vm_name]
}

resource "google_compute_firewall" "allow_gateway_ipv6" {
  count   = length(local.gateway_ipv6_cidrs) > 0 ? 1 : 0
  name    = "${var.vm_name}-allow-gateway-ipv6"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["18789"]
  }

  source_ranges = local.gateway_ipv6_cidrs
  target_tags   = [var.vm_name]
}

resource "google_compute_instance" "main" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [var.vm_name]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = var.network_name
    access_config {}
  }

  metadata = {
    ssh-keys = local.ssh_key_entry
  }

  metadata_startup_script = templatefile("${path.module}/bootstrap.sh", local.bootstrap_vars)
}
