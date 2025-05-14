terraform {
  required_providers {
    akamai = {
      source  = "akamai/akamai"
      version = ">= 7.0.0"
    }
  }
}


data "akamai_contract" "contract" {
  group_name = var.group_name
}

resource "terraform_data" "replacement" {
  input = data.akamai_contract.contract.group_id
}
