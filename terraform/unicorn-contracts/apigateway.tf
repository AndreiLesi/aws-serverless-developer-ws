
resource "aws_api_gateway_rest_api" "unicorn_contracts_api" {
  name        = "Unicorn Contracts API"
  description = "Unicorn Properties Contract Service API"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_contracts_api.id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.unicorn_contracts_api.id,
      aws_api_gateway_method.contracts_post.id,
      aws_api_gateway_method.contracts_put.id,
      aws_api_gateway_method.contracts_options.id,
      aws_api_gateway_integration.contracts_post.id,
      aws_api_gateway_integration.contracts_put.id,
      aws_api_gateway_integration.contracts_options.id,
      aws_api_gateway_integration_response.contracts_post.id,
      aws_api_gateway_integration_response.contracts_put.id,
      aws_api_gateway_integration_response.contracts_options.id,
      aws_api_gateway_method_response.contracts_post.id,
      aws_api_gateway_method_response.contracts_put.id,
      aws_api_gateway_method_response.contracts_options.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  deployment_id        = aws_api_gateway_deployment.this.id
  rest_api_id          = aws_api_gateway_rest_api.unicorn_contracts_api.id
  stage_name           = "prod"
  xray_tracing_enabled = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.UnicornContractsApiLogGroup.arn
    format = jsonencode({
      requestId                     = "$context.requestId",
      integration-error             = "$context.integration.error",
      integration-status            = "$context.integration.status",
      integration-latency           = "$context.integration.latency",
      integration-requestId         = "$context.integration.requestId",
      integration-integrationStatus = "$context.integration.integrationStatus",
      response-latency              = "$context.responseLatency",
      status                        = "$context.status"
    })
  }
}

resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = module.iam_role_ApiGatewayAccountConfigRole.iam_role_arn
}

###########
# RESOURCES
###########
resource "aws_api_gateway_resource" "contracts" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_contracts_api.id
  parent_id   = aws_api_gateway_rest_api.unicorn_contracts_api.root_resource_id
  path_part   = "contracts"
}

#########
# METHODS
#########
resource "aws_api_gateway_method" "contracts_post" {
  rest_api_id   = aws_api_gateway_rest_api.unicorn_contracts_api.id
  resource_id   = aws_api_gateway_resource.contracts.id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.validate_body.id

  request_models = {
    "application/json" = aws_api_gateway_model.create_contract_model.name
  }
}

resource "aws_api_gateway_method" "contracts_put" {
  rest_api_id   = aws_api_gateway_rest_api.unicorn_contracts_api.id
  resource_id   = aws_api_gateway_resource.contracts.id
  http_method   = "PUT"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.validate_body.id

  request_models = {
    "application/json" = aws_api_gateway_model.update_contract_model.name
  }
}

resource "aws_api_gateway_method" "contracts_options" {
  rest_api_id   = aws_api_gateway_rest_api.unicorn_contracts_api.id
  resource_id   = aws_api_gateway_resource.contracts.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}


##############
# INTEGRATIONS
##############
resource "aws_api_gateway_integration" "contracts_post" {
  rest_api_id             = aws_api_gateway_rest_api.unicorn_contracts_api.id
  resource_id             = aws_api_gateway_resource.contracts.id
  http_method             = aws_api_gateway_method.contracts_post.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  credentials             = module.iam_role_UnicornContractsApiIntegrationRole.iam_role_arn
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sqs:path/${data.aws_caller_identity.current.account_id}/${module.sqs_contracts_ingest.queue_name}"
  passthrough_behavior    = "NEVER"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body&MessageAttribute.1.Name=HttpMethod&MessageAttribute.1.Value.StringValue=$context.httpMethod&MessageAttribute.1.Value.DataType=String"
  }
}

resource "aws_api_gateway_integration" "contracts_put" {
  rest_api_id             = aws_api_gateway_rest_api.unicorn_contracts_api.id
  resource_id             = aws_api_gateway_resource.contracts.id
  http_method             = aws_api_gateway_method.contracts_put.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  credentials             = module.iam_role_UnicornContractsApiIntegrationRole.iam_role_arn
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sqs:path/${data.aws_caller_identity.current.account_id}/${module.sqs_contracts_ingest.queue_name}"
  passthrough_behavior    = "NEVER"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body&MessageAttribute.1.Name=HttpMethod&MessageAttribute.1.Value.StringValue=$context.httpMethod&MessageAttribute.1.Value.DataType=String"
  }
}

resource "aws_api_gateway_integration" "contracts_options" {
  rest_api_id          = aws_api_gateway_rest_api.unicorn_contracts_api.id
  resource_id          = aws_api_gateway_resource.contracts.id
  http_method          = aws_api_gateway_method.contracts_options.http_method
  type                 = "MOCK"
  passthrough_behavior = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "contracts_post" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_contracts_api.id
  resource_id = aws_api_gateway_resource.contracts.id
  http_method = aws_api_gateway_method.contracts_post.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "contracts_put" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_contracts_api.id
  resource_id = aws_api_gateway_resource.contracts.id
  http_method = aws_api_gateway_method.contracts_put.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "contracts_options" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_contracts_api.id
  resource_id = aws_api_gateway_resource.contracts.id
  http_method = aws_api_gateway_method.contracts_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "contracts_post" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_contracts_api.id
  resource_id = aws_api_gateway_resource.contracts.id
  http_method = aws_api_gateway_method.contracts_post.http_method
  status_code = aws_api_gateway_method_response.contracts_post.status_code
  depends_on = [
    aws_api_gateway_integration.contracts_put,
    aws_api_gateway_method.contracts_put
  ]

  response_templates = {
    "application/json" = jsonencode({
      message = "OK"
    })
  }
}

resource "aws_api_gateway_integration_response" "contracts_put" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_contracts_api.id
  resource_id = aws_api_gateway_resource.contracts.id
  http_method = aws_api_gateway_method.contracts_put.http_method
  status_code = aws_api_gateway_method_response.contracts_put.status_code
  depends_on = [
    aws_api_gateway_integration.contracts_put,
    aws_api_gateway_method.contracts_put
    ]
  response_templates = {
    "application/json" = jsonencode({
      message = "OK"
    })
  }
}

resource "aws_api_gateway_integration_response" "contracts_options" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_contracts_api.id
  resource_id = aws_api_gateway_resource.contracts.id
  http_method = aws_api_gateway_method.contracts_options.http_method
  status_code = aws_api_gateway_method_response.contracts_options.status_code
  depends_on = [
    aws_api_gateway_integration.contracts_put,
    aws_api_gateway_method.contracts_put
    ]

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_model" "create_contract_model" {
  rest_api_id  = aws_api_gateway_rest_api.unicorn_contracts_api.id
  name         = "CreateContractModel"
  description  = "Create Contract Model"
  content_type = "application/json"

  schema = jsonencode({
    type     = "object"
    required = ["property_id", "seller_name", "address"]
    properties = {
      property_id = {
        type = "string"
      }
      seller_name = {
        type = "string"
      }
      address = {
        type     = "object"
        required = ["city", "country", "number", "street"]
        properties = {
          country = {
            type = "string"
          }
          city = {
            type = "string"
          }
          street = {
            type = "string"
          }
          number = {
            type = "integer"
          }
        }
      }
    }
  })
}

resource "aws_api_gateway_model" "update_contract_model" {
  rest_api_id  = aws_api_gateway_rest_api.unicorn_contracts_api.id
  name         = "UpdateContractModel"
  description  = "Update Contract Model"
  content_type = "application/json"

  schema = jsonencode({
    type     = "object"
    required = ["property_id"]
    properties = {
      property_id = {
        type = "string"
      }
    }
  })
}

resource "aws_api_gateway_request_validator" "validate_body" {
  name                        = "Validate body"
  rest_api_id                 = aws_api_gateway_rest_api.unicorn_contracts_api.id
  validate_request_body       = true
  validate_request_parameters = false
}
