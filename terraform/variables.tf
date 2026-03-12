# ─────────────────────────────────────────────────────────────
# Variables for Oracle Cloud Infrastructure (OCI) Deployment
# ─────────────────────────────────────────────────────────────

# ── OCI Authentication ──────────────────────────────────────

variable "tenancy_ocid" {
  description = "OCID of your OCI tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the OCI user"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the OCI API signing key"
  type        = string
}

variable "private_key_path" {
  description = "Path to the OCI API private key PEM file"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment to deploy into"
  type        = string
}

# ── Region & Instance Config ────────────────────────────────

variable "region" {
  description = "OCI region to deploy into"
  type        = string
  default     = "ap-mumbai-1"
}

variable "instance_shape" {
  description = "Compute instance shape (VM.Standard.E2.1.Micro is Always Free)"
  type        = string
  default     = "VM.Standard.E2.1.Micro"
}

variable "instance_ocpus" {
  description = "Number of OCPUs for the instance"
  type        = number
  default     = 1
}

variable "instance_memory_gb" {
  description = "Memory in GB for the instance"
  type        = number
  default     = 1
}

# ── SSH & Security ──────────────────────────────────────────

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance (restrict in production)"
  type        = string
  default     = "0.0.0.0/0"
}
