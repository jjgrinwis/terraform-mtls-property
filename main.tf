terraform {
  required_providers {
    akamai = {
      source  = "akamai/akamai"
      version = ">= 7.0.0"
    }
  }
}



locals {
  # to make life as easy as possible, customer can just provide a comma separated list of hostnames.
  # script will make some nice list of of it
  raw_list  = split(",", var.hostnames)
  hostnames = [for item in local.raw_list : trimspace(item)]

  # dynamically create property name and cpcode from the first entry in the list
  # we might want to add some validation in the variables.tf to make sure correct format is provided.
  hostname_parts = regex("^([^.]+)\\.s(\\d+)\\.(.+)$", local.hostnames[0])
  property_name  = format("%s.%s.%s", local.hostname_parts[0], local.hostname_parts[1], local.hostname_parts[2])

  # using ION as our default product in case wrong product type has been provided as input var.
  default_product = "prd_Fresca"

  # convert the list of maps to a map of maps with entry.hostname as key of the map
  # this map of maps will be fed into our EdgeDNS module to create the CNAME records.
  dv_records = { for entry in resource.akamai_property.aka_property.hostnames[*].cert_status[0] : entry.hostname => entry }

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

resource "akamai_property" "aka_property" {
  name        = local.property_name
  contract_id = data.akamai_contract.contract.id
  group_id    = data.akamai_contract.contract.group_id
  product_id  = resource.akamai_cp_code.cp_code.product_id
  rule_format = "latest"


  # A dynamic block of hostnames.
  dynamic "hostnames" {
    for_each = toset(local.hostnames)
    content {
      cname_from             = hostnames.key
      cname_to               = "${hostnames.key}.${var.domain_suffix}"
      cert_provisioning_type = "DEFAULT"
    }
  }

  # rules created via akamai pm show-ruletree --section gss -a F-AC-1020908:1-5G3LB -p Externe_Plannings_Visualisatie | jq .rules > rules.json
  # json modified so it will dynamically create the different origins
  rules = templatefile("template/rules.tftpl", { hostnames = local.hostnames, cpcode = tonumber(resource.akamai_cp_code.cp_code.id) })
}

# just add some CNAMEs for the SBD certificates. Make sure you have the credentials to also update DNS records!
resource "akamai_dns_record" "dv_cname" {

  # loop through each item in our known hostnames set
  for_each = toset(local.hostnames)

  # get the key or value, same in this instance 
  zone = regex("[^.]+\\.[^.]+$", each.key)
  name = "_acme-challenge.${each.value}"

  # let's lookup target value from our map of maps with value from hostnames[] as key
  target = [lookup(local.dv_records["_acme-challenge.${each.value}"], "target")]

  recordtype = "CNAME"
  ttl        = 60
}

