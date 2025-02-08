module "unicorn_contracts" {
  source  = "./unicorn-contracts/"
  project = local.project
}

module "unicorn_properties" {
  source  = "./unicorn-properties/"
  project = local.project
}