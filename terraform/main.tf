# ─────────────────────────────────────────────────────────────
# Cloud System Monitor – Oracle Cloud Infrastructure (OCI)
# Provisions a free-tier compute instance with networking
# ─────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

# ── Provider ────────────────────────────────────────────────
provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# ── Data: Availability Domain ───────────────────────────────
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# ── Data: Latest Oracle Linux Image ─────────────────────────
data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# ── VCN (Virtual Cloud Network) ─────────────────────────────
resource "oci_core_vcn" "monitor_vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "cloud-monitor-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "monitorvcn"
}

# ── Internet Gateway ────────────────────────────────────────
resource "oci_core_internet_gateway" "monitor_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.monitor_vcn.id
  display_name   = "cloud-monitor-igw"
  enabled        = true
}

# ── Route Table ─────────────────────────────────────────────
resource "oci_core_route_table" "monitor_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.monitor_vcn.id
  display_name   = "cloud-monitor-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.monitor_igw.id
  }
}

# ── Security List ───────────────────────────────────────────
resource "oci_core_security_list" "monitor_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.monitor_vcn.id
  display_name   = "cloud-monitor-sl"

  # ── Egress: Allow all outbound ────────────────────────────
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  # ── Ingress: SSH (port 22) ────────────────────────────────
  ingress_security_rules {
    protocol  = "6" # TCP
    source    = var.allowed_ssh_cidr
    stateless = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  # ── Ingress: Flask App (port 5000) ────────────────────────
  ingress_security_rules {
    protocol  = "6" # TCP
    source    = "0.0.0.0/0"
    stateless = false

    tcp_options {
      min = 5000
      max = 5000
    }
  }

  # ── Ingress: ICMP (ping) ─────────────────────────────────
  ingress_security_rules {
    protocol  = "1" # ICMP
    source    = "0.0.0.0/0"
    stateless = false
  }
}

# ── Subnet ──────────────────────────────────────────────────
resource "oci_core_subnet" "monitor_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.monitor_vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "cloud-monitor-subnet"
  dns_label         = "monitorsub"
  route_table_id    = oci_core_route_table.monitor_rt.id
  security_list_ids = [oci_core_security_list.monitor_sl.id]
}

# ── Compute Instance (Always Free Tier) ─────────────────────
resource "oci_core_instance" "monitor_instance" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "cloud-system-monitor"
  shape               = var.instance_shape

  # Free-tier shape config (1 OCPU, 1 GB RAM for AMD micro)
  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.monitor_subnet.id
    assign_public_ip = true
    display_name     = "cloud-monitor-vnic"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(<<-EOF
      #!/bin/bash
      set -e

      # Install Docker
      sudo yum install -y yum-utils
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo yum install -y docker-ce docker-ce-cli containerd.io
      sudo systemctl start docker
      sudo systemctl enable docker
      sudo usermod -aG docker opc

      # Open firewall for port 5000
      sudo firewall-cmd --permanent --add-port=5000/tcp
      sudo firewall-cmd --reload
    EOF
    )
  }

  freeform_tags = {
    "Project" = "CloudSystemMonitor"
  }
}
