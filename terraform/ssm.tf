resource "aws_ssm_parameter" "ImageBucket" {
  name  = "/uni-prop/prod/ImagesBucket"
  type  = "String"
  value = aws_s3_bucket.images.bucket
}

resource "aws_ssm_parameter" "ContractsNamespace" {
  name  = "/uni-prop/UnicornContractsNamespace"
  type  = "String"
  value = "unicorn.contracts"
}

resource "aws_ssm_parameter" "PropertiesNamespace" {
  name  = "/uni-prop/UnicornPropertiesNamespace"
  type  = "String"
  value = "unicorn.properties"
}

resource "aws_ssm_parameter" "WebNamespace" {
  name  = "/uni-prop/UnicornWebNamespace"
  type  = "String"
  value = "unicorn.web"
}

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
