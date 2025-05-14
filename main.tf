terraform {
  required_providers {
    akamai = {
      source  = "akamai/akamai"
      version = ">= 7.0.0"
    }
  }
}

locals {
  # using ION as our default product in case wrong product type has been provided as input var.
  default_product = "prd_Fresca"

  # secure network or not. This var is used to set a secure option in the delivery config
  secure_network = var.domain_suffix == "edgekey.net" ? true : false
}

# lookup our group info based on provided group name
data "akamai_contract" "contract" {
  group_name = var.group_name
}

# for the demo don't create cpcode's over and over again, just reuse existing one
# if cpcode already existst it will take the existing one. If selecting existing one, make sure it's unique.
resource "akamai_cp_code" "cp_code" {
  name        = var.cpcode
  contract_id = data.akamai_contract.contract.id
  group_id    = data.akamai_contract.contract.group_id
  product_id  = lookup(var.aka_products, lower(var.product_name), local.default_product)
}

# as the config will be pretty static, use template file
# we're going to use all required rules in this tf file.
# create our edge hostname resource
resource "akamai_edge_hostname" "aka_edge" {

  product_id  = resource.akamai_cp_code.cp_code.product_id
  contract_id = data.akamai_contract.contract.id
  group_id    = data.akamai_contract.contract.group_id
  ip_behavior = var.ip_behavior

  # edgehostname based on hostname + networkf(FF/ESSL)
  edge_hostname = "${var.hostname}.${var.domain_suffix}"
}

resource "akamai_property" "aka_property" {
  name        = var.hostname
  contract_id = data.akamai_contract.contract.id
  group_id    = data.akamai_contract.contract.group_id
  product_id  = resource.akamai_cp_code.cp_code.product_id
  rule_format = var.rule_format

  # our pretty static hostname configuration so a simple 1:1 between front-end and back-end
  hostnames {
    cname_from             = var.hostname
    cname_to               = "${var.hostname}.${var.domain_suffix}"
    cert_provisioning_type = "CPS_MANAGED"
  }

  # rules created via 'akamai terraform export-property --rules-as-hcl property_template_name`
  # updated the origin hostname and cpcode that are based on input vars.
  rules = data.akamai_property_rules_builder.tf-hcp-test_rule_default.json
}

