# edgrc credentials should be provided via terraform cloud
provider "akamai" {
  required_version = ">=7.0.0"
}

data "akamai_contract" "contract" {
  group_name = var.group_name
}
