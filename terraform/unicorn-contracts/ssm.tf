resource "aws_ssm_parameter" "UnicornContractsEventBusNameParam" {
  name  = "/uni-prop/prod/UnicornContractsEventBus"
  type  = "String"
  value = module.eventbridge_contracts_bus.eventbridge_bus_name
}

resource "aws_ssm_parameter" "UnicornContractsEventBusArnParam" {
  name  = "/uni-prop/prod/UnicornContractsEventBusArn"
  type  = "String"
  value = module.eventbridge_contracts_bus.eventbridge_bus_arn
}
