output "hostnames" {
  description = "Hostnames added to the property"
  value       = local.hostnames
}

output "dv_records" {
  description = "Our CNAME records for SBD will also contain the deployment status"
  value       = local.dv_records
}
output "proprty_name" {
  description = "Name the property and cpcode"
  value       = local.property_name
}
