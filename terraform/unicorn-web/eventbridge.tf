module "eventbridge_unicorn_web_bus" {
  source = "terraform-aws-modules/eventbridge/aws"

  bus_name = "UnicornWebEventBus-Prod"

  rules = {
    "web.catchall" = {
      enabled     = true
      description = "Catch all events published to the web service."
      event_pattern = jsonencode({
        "account" : [data.aws_caller_identity.current.account_id]
        "source" : [
          data.aws_ssm_parameter.ContractsNamespace.value,
          data.aws_ssm_parameter.PropertiesNamespace.value,
          data.aws_ssm_parameter.WebNamespace.value,
        ]
      })
    },
    "TriggerLambdaOnPublicationApproved" = {
      enabled     = true
      description = "Trigger Lambda on Publication Approved event."
      event_pattern = jsonencode({
        "source"      : [data.aws_ssm_parameter.PropertiesNamespace.value],
        "detail-type" : ["PublicationEvaluationCompleted"]
      })
    }
  }

  targets = {
    "web.catchall" = [
      {
        name = "UnicornWebCatchAllLogGroupTarget-Prod"
        arn  = aws_cloudwatch_log_group.UnicornWebCatchAllLogGroup.arn
      }
    ],
    "TriggerLambdaOnPublicationApproved" = [
      {
        name = "TriggerLambdaOnPublicationApproved"
        arn  = module.lambda_publication_approved_event_handler.lambda_function_arn
      }
    ]
  }

  attach_tracing_policy    = true
  attach_cloudwatch_policy = true
  cloudwatch_target_arns   = [aws_cloudwatch_log_group.UnicornWebCatchAllLogGroup.arn]
}

# Unicorn Web Publish Policy
resource "aws_cloudwatch_event_bus_policy" "contract_events_publish_policy" {
  event_bus_name = module.eventbridge_unicorn_web_bus.eventbridge_bus_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WebPublishEventsPolicy"
        Effect = "Allow"
        Action = "events:PutEvents"
        Principal = {
          AWS = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
        }
        Resource = module.eventbridge_unicorn_web_bus.eventbridge_bus_arn
        Condition = {
          StringEquals = {
            "events:source" = [data.aws_ssm_parameter.WebNamespace.value]
          }
        }
      },
      {
        Sid    = "OnlyRulesForWeberviceEvents"
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
        Resource = "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/${module.eventbridge_unicorn_web_bus.eventbridge_bus_name}/*"
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
resource "aws_schemas_registry" "web_event" {
  name = data.aws_ssm_parameter.WebNamespace.value
}

resource "aws_schemas_registry_policy" "web_event_policy" {
  registry_name = aws_schemas_registry.web_event.name
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
          AWS = [data.aws_caller_identity.current.account_id]
        }
        Resource = [
          "arn:aws:schemas:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:schema/${aws_schemas_registry.web_event.name}*"
        ]
      }
    ]
  })
}

# # Schema: Contract Status Changed 
# resource "aws_schemas_schema" "contracts_contract_status_changed" {
#   name          = "unicorn.contracts@ContractStatusChanged"
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

##########################################################################
# Subscription to Properties Bus for PublicationEvaluationCompleted  event
##########################################################################
resource "aws_cloudwatch_event_rule" "publication_evaluation_completed" {
  name           = "unicorn.properties-PublicationEvaluationCompleted"
  description    = "Publication Evaluation Completed subscription"
  event_bus_name = data.aws_cloudwatch_event_bus.properties.name

  event_pattern = jsonencode({
    source      = [data.aws_ssm_parameter.PropertiesNamespace.value]
    detail-type = ["PublicationEvaluationCompleted"]
  })
}

resource "aws_cloudwatch_event_target" "publication_evaluation_completed" {
  rule           = aws_cloudwatch_event_rule.publication_evaluation_completed.name
  event_bus_name = data.aws_cloudwatch_event_bus.properties.name
  target_id      = "SendEventToPropertiesBus"
  arn            = module.eventbridge_unicorn_web_bus.eventbridge_bus_arn
  role_arn       = module.iam_role_web_properties_subscription.iam_role_arn
}

##########################################################################
# Push Publication Approval Requested events to the Properties Bus
##########################################################################
resource "aws_cloudwatch_event_rule" "request_approval_event_subscription" {
  name           = "SendRequestApprovalEventToPropertiesBus"
  description    = "Send Request Approval event to Properties Bus"
  event_bus_name = module.eventbridge_unicorn_web_bus.eventbridge_bus_name

  event_pattern = jsonencode({
    source      = [data.aws_ssm_parameter.WebNamespace.value]
    detail-type = ["PublicationApprovalRequested"]
  })
}

resource "aws_cloudwatch_event_target" "request_approval_event_subscription" {
  rule           = aws_cloudwatch_event_rule.request_approval_event_subscription.name
  event_bus_name = module.eventbridge_unicorn_web_bus.eventbridge_bus_name
  target_id      = "SendEventToPropertiesBus"
  arn            = data.aws_cloudwatch_event_bus.properties.arn
  role_arn       = module.iam_role_web_to_properties_push.iam_role_arn
}
