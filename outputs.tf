output "hostname" {
  description = "Our configured host/property name"
  value       = var.hostname
}

output "mappings" {
  description = "Assigned certificate"
  value       = var.host_mappings
}
