terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# ── Networking ──────────────────────────────────────────────

resource "oci_core_vcn" "openclaw_vcn" {
  compartment_id = var.compartment_id
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "openclaw-vcn"
}

resource "oci_core_internet_gateway" "openclaw_igw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.openclaw_vcn.id
  display_name   = "openclaw-igw"
  enabled        = true
}

resource "oci_core_route_table" "openclaw_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.openclaw_vcn.id
  display_name   = "openclaw-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.openclaw_igw.id
  }
}

resource "oci_core_security_list" "openclaw_sl" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.openclaw_vcn.id
  display_name   = "openclaw-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 18789
      max = 18789
    }
  }
}

resource "oci_core_subnet" "openclaw_subnet" {
  compartment_id    = var.compartment_id
  vcn_id            = oci_core_vcn.openclaw_vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "openclaw-subnet"
  route_table_id    = oci_core_route_table.openclaw_rt.id
  security_list_ids = [oci_core_security_list.openclaw_sl.id]
}

# ── Container Instance ───────────────────────────────────────

resource "oci_container_instances_container_instance" "openclaw" {
  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  display_name        = "openclaw-host"

  shape = "CI.Standard.A1.Flex"
  shape_config {
    ocpus         = 1
    memory_in_gbs = 2
  }

  vnics {
    subnet_id        = oci_core_subnet.openclaw_subnet.id
    is_public_ip_assigned = true
    display_name     = "openclaw-vnic"
  }

  containers {
    display_name = "openclaw-gateway"
    image_url    = "ghcr.io/openclaw/openclaw:latest"

    environment_variables = {
      OPENROUTER_API_KEY              = var.openrouter_api_key
      TELEGRAM_BOT_TOKEN              = var.telegram_bot_token
      OPENCLAW_GATEWAY_TOKEN          = var.openclaw_gateway_token
      OPENCLAW_ONBOARD_NON_INTERACTIVE = "1"
    }

    resource_config {
      memory_limit_in_gbs = 1.5
      vcpus_limit         = 1
    }
  }
}

# ── Outputs ──────────────────────────────────────────────────

output "container_instance_id" {
  value = oci_container_instances_container_instance.openclaw.id
}

output "public_ip" {
  value = oci_container_instances_container_instance.openclaw.vnics[0].hostname_label
}