module "shared_infra" {
  source  = "./shared-infra/"
  project = local.project
}

module "unicorn_contracts" {
  source  = "./unicorn-contracts/"
  project = local.project

  depends_on = [ module.shared_infra ]
}

# module "unicorn_properties" {
#   source  = "./unicorn-properties/"
#   project = local.project

#   depends_on = [ 
#     module.shared_infra,
#     module.unicorn_contracts
#   ]
# }
