# ─────────────────────────────────────────────────────────────
# Outputs
# ─────────────────────────────────────────────────────────────

output "instance_public_ip" {
  description = "Public IP address of the compute instance"
  value       = oci_core_instance.monitor_instance.public_ip
}

output "instance_id" {
  description = "OCID of the compute instance"
  value       = oci_core_instance.monitor_instance.id
}

output "dashboard_url" {
  description = "URL to access the monitoring dashboard"
  value       = "http://${oci_core_instance.monitor_instance.public_ip}:5000"
}

output "vcn_id" {
  description = "OCID of the Virtual Cloud Network"
  value       = oci_core_vcn.monitor_vcn.id
}
