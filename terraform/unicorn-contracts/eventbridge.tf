module "eventbridge_contracts_bus" {
  source = "terraform-aws-modules/eventbridge/aws"

  bus_name = "UnicornContractsBus-Prod"

  rules = {
    "contracts.catchall" = {
      description = "Catch all events published by the contracts service."
      event_pattern = jsonencode({
        "account" : [data.aws_caller_identity.current.account_id]
        "source" : [
          data.aws_ssm_parameter.ContractsNamespace.value,
          data.aws_ssm_parameter.PropertiesNamespace.value,
          data.aws_ssm_parameter.WebNamespace.value,
        ]
      })
      enabled = true
    }
  }

  targets = {
    "contracts.catchall" = [
      {
        name = "UnicornContractsCatchAllLogGroupTarget-Prod"
        arn  = aws_cloudwatch_log_group.UnicornContractsCatchAllLogGroup.arn
      }
    ]
  }

  attach_tracing_policy    = true
  attach_cloudwatch_policy = true
  cloudwatch_target_arns   = [aws_cloudwatch_log_group.UnicornContractsCatchAllLogGroup.arn]
}

# Restrict Permissions of Eventbus
resource "aws_cloudwatch_event_bus_policy" "contract_events_publish_policy" {
  event_bus_name = module.eventbridge_contracts_bus.eventbridge_bus_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OnlyContractServiceCanPublishToEventBus"
        Effect = "Allow"
        Action = "events:PutEvents"
        Principal = {
          AWS = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
        }
        Resource = module.eventbridge_contracts_bus.eventbridge_bus_arn
        Condition = {
          StringEquals = {
            "events:source" = [data.aws_ssm_parameter.ContractsNamespace.value]
          }
        }
      },
      {
        Sid    = "OnlyRulesForContractServiceEvents"
        Effect = "Allow"
        Action = [
          "events:PutRule",
          "events:DeleteRule",
          "events:DescribeRule",
          "events:DisableRule",
          "events:EnableRule",
          "events:PutTargets",
          "events:RemoveTargets"
        ]
        Principal = {
          AWS = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
        }
        Resource = module.eventbridge_contracts_bus.eventbridge_bus_arn
        Condition = {
          StringEquals = {
            "events:source" = [data.aws_ssm_parameter.ContractsNamespace.value]
          },
          StringEqualsIfExists = {
            "events:creatorAccount" = data.aws_caller_identity.current.account_id
          },
          Null = {
            "events:source" = false
          }
        }
      }
    ]
  })
}

### Create Event Registry for Unicorn Contracts
resource "aws_schemas_registry" "contracts_event" {
  name = data.aws_ssm_parameter.ContractsNamespace.value
}

resource "aws_schemas_registry_policy" "contracts_event_policy" {
  registry_name = aws_schemas_registry.contracts_event.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowExternalServices"
        Effect = "Allow"
        Action = [
          "schemas:DescribeCodeBinding",
          "schemas:DescribeRegistry",
          "schemas:DescribeSchema",
          "schemas:GetCodeBindingSource",
          "schemas:ListSchemas",
          "schemas:ListSchemaVersions",
          "schemas:SearchSchemas"
        ]
        Principal = {
          AWS = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
        }
        Resource = aws_schemas_registry.contracts_event.arn
      }
    ]
  })
}

# Schema: Contract Status Changed 
resource "aws_schemas_schema" "contracts_contract_status_changed" {
  name          = "unicorn.contracts@ContractStatusChanged"
  registry_name = aws_schemas_registry.contracts_event.name
  type          = "OpenApi3"
  content = jsonencode({
    "openapi" : "3.0.0",
    "info" : {
      "version" : "1.0.0",
      "title" : "ContractStatusChanged"
    },
    "paths" : {},
    "components" : {
      "schemas" : {
        "AWSEvent" : {
          "type" : "object",
          "required" : ["detail-type", "resources", "detail", "id", "source", "time", "region", "version", "account"],
          "x-amazon-events-detail-type" : "ContractStatusChanged",
          "x-amazon-events-source" : "unicorn.contracts",
          "properties" : {
            "detail" : {
              "$ref" : "#/components/schemas/ContractStatusChanged"
            },
            "account" : {
              "type" : "string"
            },
            "detail-type" : {
              "type" : "string"
            },
            "id" : {
              "type" : "string"
            },
            "region" : {
              "type" : "string"
            },
            "resources" : {
              "type" : "array",
              "items" : {
                "type" : "object"
              }
            },
            "source" : {
              "type" : "string"
            },
            "time" : {
              "type" : "string",
              "format" : "date-time"
            },
            "version" : {
              "type" : "string"
            }
          }
        },
        "ContractStatusChanged" : {
          "type" : "object",
          "required" : ["contract_last_modified_on", "contract_id", "contract_status", "property_id"],
          "properties" : {
            "contract_id" : {
              "type" : "string"
            },
            "contract_last_modified_on" : {
              "type" : "string"
            },
            "contract_status" : {
              "type" : "string"
            },
            "property_id" : {
              "type" : "string"
            }
          }
        }
      }
    }
    }
  )
}