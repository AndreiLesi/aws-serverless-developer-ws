module "eventbridge_properties_bus" {
  source = "terraform-aws-modules/eventbridge/aws"

  bus_name = "UnicornPropertiesBus-Prod"

  rules = {
    "properties.catchall" = {
      description = "Catch all events published by the properties service."
      event_pattern = jsonencode({
        "account" : [data.aws_caller_identity.current.account_id]
        "source" : [
          data.aws_ssm_parameter.ContractsNamespace.value,
          data.aws_ssm_parameter.PropertiesNamespace.value,
          data.aws_ssm_parameter.WebNamespace.value,
        ]
      })
      enabled = true
    },
    "properties.ContractStatusChanged" = {
      description = "Triggers the Contract Status Changed Event Lambda Fcn"
      event_pattern = jsonencode({
        "source" : [data.aws_ssm_parameter.ContractsNamespace.value],
        "detail-type" : ["ContractStatusChanged"]
      })
      enabled = true
    },
    "properties.triggerSfn" = {
      description = "Triggers Step Function when a approval is requested"
      event_pattern = jsonencode({
        "source" : [data.aws_ssm_parameter.WebNamespace.value],
        "detail-type" : ["PublicationApprovalRequested"]
      })
      enabled = true
    }
  }

  targets = {
    "properties.catchall" = [
      {
        name = "UnicornPropertiesCatchAllLogGroupTarget-Prod"
        arn  = aws_cloudwatch_log_group.UnicornPropertiesCatchAllLogGroup.arn
      }
    ],
    "properties.ContractStatusChanged" = [
      {
        name            = "UnicornPropertiesLambdaFcn-Prod"
        arn             = module.lambda_contract_status_changed_event_handler.lambda_function_arn
        dead_letter_arn = module.sqs_PropertiesEventBusRuleDLQ.queue_arn
      }
    ],
    "properties.triggerSfn" = [
      {
        name            = "UnicornProperties-SfnApprovalWF"
        arn             = module.sfn_properties_approval_state_machine.state_machine_arn
        attach_role_arn = true
        dead_letter_arn = module.sqs_PropertiesServiceDLQ.queue_arn
      }
    ]
  }

  attach_tracing_policy    = true
  attach_cloudwatch_policy = true
  cloudwatch_target_arns   = [aws_cloudwatch_log_group.UnicornPropertiesCatchAllLogGroup.arn]
  attach_sfn_policy = true
  sfn_target_arns = [module.sfn_properties_approval_state_machine.state_machine_arn]
  attach_lambda_policy = true
  lambda_target_arns = [module.lambda_contract_status_changed_event_handler.lambda_function_arn]
}

# Restrict Permissions of Eventbus
resource "aws_cloudwatch_event_bus_policy" "properties_events_publish_policy" {
  event_bus_name = module.eventbridge_properties_bus.eventbridge_bus_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OnlyPropertiesServiceCanPublishToEventBus"
        Effect = "Allow"
        Action = "events:PutEvents"
        Principal = {
          AWS = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
        }
        Resource = module.eventbridge_properties_bus.eventbridge_bus_arn
        Condition = {
          StringEquals = {
            "events:source" = [data.aws_ssm_parameter.PropertiesNamespace.value]
          }
        }
      },
      {
        Sid    = "CrossServiceCreateRulePolicy"
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
        Resource = module.eventbridge_properties_bus.eventbridge_bus_arn
        Condition = {
          StringEquals = {
            "events:source" = [data.aws_ssm_parameter.PropertiesNamespace.value]
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
resource "aws_schemas_registry" "properties_event" {
  name = data.aws_ssm_parameter.PropertiesNamespace.value
}

resource "aws_schemas_registry_policy" "properties_event_policy" {
  registry_name = aws_schemas_registry.properties_event.name
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
        Resource = aws_schemas_registry.properties_event.arn
      }
    ]
  })
}

# # Schema: Contract Status Changed 
# resource "aws_schemas_schema" "contracts_contract_status_changed" {
#   name          = "ContractStatusChanged"
#   registry_name = aws_schemas_registry.contracts_event.name
#   type          = "OpenApi3"
#   content = jsonencode({
#     "openapi" : "3.0.0",
#     "info" : {
#       "version" : "1.0.0",
#       "title" : "ContractStatusChanged"
#     },
#     "paths" : {},
#     "components" : {
#       "schemas" : {
#         "AWSEvent" : {
#           "type" : "object",
#           "required" : ["detail-type", "resources", "detail", "id", "source", "time", "region", "version", "account"],
#           "x-amazon-events-detail-type" : "ContractStatusChanged",
#           "x-amazon-events-source" : "unicorn.contracts",
#           "properties" : {
#             "detail" : {
#               "$ref" : "#/components/schemas/ContractStatusChanged"
#             },
#             "account" : {
#               "type" : "string"
#             },
#             "detail-type" : {
#               "type" : "string"
#             },
#             "id" : {
#               "type" : "string"
#             },
#             "region" : {
#               "type" : "string"
#             },
#             "resources" : {
#               "type" : "array",
#               "items" : {
#                 "type" : "object"
#               }
#             },
#             "source" : {
#               "type" : "string"
#             },
#             "time" : {
#               "type" : "string",
#               "format" : "date-time"
#             },
#             "version" : {
#               "type" : "string"
#             }
#           }
#         },
#         "ContractStatusChanged" : {
#           "type" : "object",
#           "required" : ["contract_last_modified_on", "contract_id", "contract_status", "property_id"],
#           "properties" : {
#             "contract_id" : {
#               "type" : "string"
#             },
#             "contract_last_modified_on" : {
#               "type" : "string"
#             },
#             "contract_status" : {
#               "type" : "string"
#             },
#             "property_id" : {
#               "type" : "string"
#             }
#           }
#         }
#       }
#     }
#     }
#   )
# }

#################################################
# Contracts Eventbus Rule -> Properties Event Bus
#################################################
resource "aws_cloudwatch_event_rule" "contracts_event_subscription" {
  name        = "unicorn.properties-ContractStatusChanged"
  description = "Contract Status Changed subscription"
  event_bus_name = data.aws_cloudwatch_event_bus.contracts.name

  event_pattern = jsonencode({
    source = [data.aws_ssm_parameter.ContractsNamespace.value]
    detail-type = ["ContractStatusChanged"]
  })
}

resource "aws_cloudwatch_event_target" "contracts_event_subscription" {
  rule      = aws_cloudwatch_event_rule.contracts_event_subscription.name
  event_bus_name = data.aws_cloudwatch_event_bus.contracts.name
  target_id = "SendEventTo"
  arn       = module.eventbridge_properties_bus.eventbridge_bus_arn
  role_arn  = module.iam_role_properties_subscription.iam_role_arn
}
