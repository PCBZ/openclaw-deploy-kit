locals {
  effective_container_image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.ghcr_remote_repository_id}/${var.ghcr_image_path}:${var.ghcr_image_tag}"
  futu_enabled              = var.futu_account != "" && var.futu_password_md5 != ""
  futu_skills_install       = local.futu_enabled ? file("${path.module}/futu-skills-install.sh") : ""

  openclaw_json_content = templatefile("${path.module}/../shared/openclaw.json.tpl", {
    openclaw_gateway_token = var.openclaw_gateway_token
    openrouter_api_key     = var.openrouter_api_key
    brave_api_key          = var.brave_api_key
    telegram_bot_token     = var.telegram_bot_token
    slack_app_token        = var.slack_app_token
    slack_bot_token        = var.slack_bot_token
    slack_enabled          = true   # Cloud Run always provisions Slack secrets
    bonjour_enabled        = true   # Cloud Run: disable bonjour discovery
    use_plugin_load_paths  = false  # Cloud Run: extensions bundled in container image
    telegram_owner_id      = var.telegram_owner_id
  })
}

resource "google_project_service" "required" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "compute.googleapis.com"
  ])

  project                    = var.project_id
  service                    = each.key
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_artifact_registry_repository" "ghcr_remote" {
  project       = var.project_id
  location      = var.region
  repository_id = var.ghcr_remote_repository_id
  description   = var.ghcr_remote_repository_description
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"

  remote_repository_config {
    description = "GitHub Container Registry proxy"
    docker_repository {
      custom_repository {
        uri = var.ghcr_upstream_uri
      }
    }
  }

  depends_on = [google_project_service.required]
}

resource "tls_private_key" "futu_rsa" {
  count     = local.futu_enabled ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 1024
}

resource "google_compute_instance" "futu_opend" {
  count        = local.futu_enabled ? 1 : 0
  name         = "${var.service_name}-futu-opend"
  machine_type = "e2-micro"
  zone         = "${var.region}-b"
  project      = var.project_id
  tags         = ["${var.service_name}-futu-opend"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    startup-script = templatefile("${path.module}/futu-opend-startup.sh", {
      futu_account       = var.futu_account
      futu_password_md5  = var.futu_password_md5
      futu_rsa_private_key = tls_private_key.futu_rsa[0].private_key_pem
    })
  }

  depends_on = [google_project_service.required]
}

resource "google_compute_firewall" "futu_opend_api" {
  count   = local.futu_enabled ? 1 : 0
  name    = "${var.service_name}-futu-opend-api"
  network = "default"
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["11111"]
  }

  source_ranges = ["10.0.0.0/8"]
  target_tags   = ["${var.service_name}-futu-opend"]
}

resource "google_artifact_registry_repository_iam_member" "ghcr_remote_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.ghcr_remote.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.cloudrun.email}"
}
