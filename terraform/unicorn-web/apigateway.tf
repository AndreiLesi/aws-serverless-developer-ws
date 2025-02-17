# API Gateway - Unicorn Web API
resource "aws_api_gateway_rest_api" "unicorn_web_api" {
  name        = "Unicorn Web API"
  description = "Unicorn Properties Web Service API"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_account" "unicorn_web" {
  cloudwatch_role_arn = module.iam_role_UnicornWebApiGwAccountConfigRole.iam_role_arn
}

resource "aws_api_gateway_deployment" "unicorn_web_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_web_api.id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.request_approval.id,
      aws_api_gateway_resource.search.id,
      aws_api_gateway_resource.search_country.id,
      aws_api_gateway_resource.search_country_city.id,
      aws_api_gateway_resource.search_country_city_street.id,
      aws_api_gateway_resource.search_country_city_street_number.id,
      aws_api_gateway_method.request_approval_post.id,
      aws_api_gateway_method.search_country_city_get.id,
      aws_api_gateway_method.search_country_city_street_get.id,
      aws_api_gateway_method.search_country_city_street_number_get.id,
      aws_api_gateway_integration.request_approval_post.id,
      aws_api_gateway_integration.search_country_city_get.id,
      aws_api_gateway_integration.search_country_city_street_get.id,
      aws_api_gateway_integration.search_country_city_street_number_get.id,
      aws_api_gateway_integration_response.request_approval_post_200.id,
      aws_api_gateway_method_response.request_approval_post_200.id,
      aws_api_gateway_method_response.search_country_city_get_200.id,
      aws_api_gateway_method_response.search_country_city_street_get_200.id,
      aws_api_gateway_method_response.search_country_city_street_number_get_200.id
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "unicorn_web_api_stage" {
  deployment_id        = aws_api_gateway_deployment.unicorn_web_api_deployment.id
  rest_api_id          = aws_api_gateway_rest_api.unicorn_web_api.id
  stage_name           = "prod"
  xray_tracing_enabled = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.UnicornWebApiGateway.arn
    format = jsonencode({
      requestId                     = "$context.requestId"
      integration-error             = "$context.integration.error"
      integration-status            = "$context.integration.status"
      integration-latency           = "$context.integration.latency"
      integration-requestId         = "$context.integration.requestId"
      integration-integrationStatus = "$context.integration.integrationStatus"
      response-latency              = "$context.responseLatency"
      status                        = "$context.status"
    })
  }
}

############
# Resources
############
resource "aws_api_gateway_resource" "request_approval" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_web_api.id
  parent_id   = aws_api_gateway_rest_api.unicorn_web_api.root_resource_id
  path_part   = "request_approval"
}

resource "aws_api_gateway_resource" "search" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_web_api.id
  parent_id   = aws_api_gateway_rest_api.unicorn_web_api.root_resource_id
  path_part   = "search"
}

resource "aws_api_gateway_resource" "search_country" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_web_api.id
  parent_id   = aws_api_gateway_resource.search.id
  path_part   = "{country}"
}

resource "aws_api_gateway_resource" "search_country_city" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_web_api.id
  parent_id   = aws_api_gateway_resource.search_country.id
  path_part   = "{city}"
}

resource "aws_api_gateway_resource" "search_country_city_street" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_web_api.id
  parent_id   = aws_api_gateway_resource.search_country_city.id
  path_part   = "{street}"
}

resource "aws_api_gateway_resource" "search_country_city_street_number" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_web_api.id
  parent_id   = aws_api_gateway_resource.search_country_city_street.id
  path_part   = "{number}"
}


##############################
# Method Request Approval POST
##############################

resource "aws_api_gateway_method" "request_approval_post" {
  rest_api_id          = aws_api_gateway_rest_api.unicorn_web_api.id
  resource_id          = aws_api_gateway_resource.request_approval.id
  http_method          = "POST"
  authorization        = "NONE"
  request_validator_id = aws_api_gateway_request_validator.validate_body.id
  request_models = {
    "application/json" = aws_api_gateway_model.publication_evaluation_request_model.name
  }
}

resource "aws_api_gateway_integration" "request_approval_post" {
  rest_api_id             = aws_api_gateway_rest_api.unicorn_web_api.id
  resource_id             = aws_api_gateway_resource.request_approval.id
  http_method             = aws_api_gateway_method.request_approval_post.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sqs:path/${data.aws_caller_identity.current.account_id}/${module.sqs_UnicornWebIngestQueue.queue_name}"
  credentials             = module.iam_role_UnicornWebApiIntegrationRole.iam_role_arn

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body"
  }

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  passthrough_behavior = "NEVER"
}

resource "aws_api_gateway_integration_response" "request_approval_post_200" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_web_api.id
  resource_id = aws_api_gateway_resource.request_approval.id
  http_method = aws_api_gateway_method.request_approval_post.http_method
  status_code = "200"
  response_templates = {
    "application/json" = "{\"message\":\"OK\"}"
  }
}

resource "aws_api_gateway_method_response" "request_approval_post_200" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_web_api.id
  resource_id = aws_api_gateway_resource.request_approval.id
  http_method = aws_api_gateway_method.request_approval_post.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  
}

################################
# Method Search/Country/City GET
################################

resource "aws_api_gateway_method" "search_country_city_get" {
  rest_api_id   = aws_api_gateway_rest_api.unicorn_web_api.id
  resource_id   = aws_api_gateway_resource.search_country_city.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.country" = true
    "method.request.path.city"    = true
  }
}

resource "aws_api_gateway_integration" "search_country_city_get" {
  rest_api_id             = aws_api_gateway_rest_api.unicorn_web_api.id
  resource_id             = aws_api_gateway_resource.search_country_city.id
  http_method             = aws_api_gateway_method.search_country_city_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_web_search_function.lambda_function_invoke_arn
  credentials             = module.iam_role_UnicornWebApiIntegrationRole.iam_role_arn
  passthrough_behavior    = "WHEN_NO_MATCH"
  content_handling        = "CONVERT_TO_TEXT"
}

resource "aws_api_gateway_method_response" "search_country_city_get_200" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_web_api.id
  resource_id = aws_api_gateway_resource.search_country_city.id
  http_method = aws_api_gateway_method.search_country_city_get.http_method
  status_code = "200"

  response_models = {
    "application/json" = aws_api_gateway_model.list_properties_response_body.name
  }
}

#######################################
# Method Search/Country/City/street GET
#######################################

resource "aws_api_gateway_method" "search_country_city_street_get" {
  rest_api_id   = aws_api_gateway_rest_api.unicorn_web_api.id
  resource_id   = aws_api_gateway_resource.search_country_city_street.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.country" = true
    "method.request.path.city"    = true
    "method.request.path.street"  = true
  }
}

resource "aws_api_gateway_integration" "search_country_city_street_get" {
  rest_api_id             = aws_api_gateway_rest_api.unicorn_web_api.id
  resource_id             = aws_api_gateway_resource.search_country_city_street.id
  http_method             = aws_api_gateway_method.search_country_city_street_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_web_search_function.lambda_function_invoke_arn
  credentials             = module.iam_role_UnicornWebApiIntegrationRole.iam_role_arn
  passthrough_behavior    = "WHEN_NO_MATCH"
  content_handling        = "CONVERT_TO_TEXT"
}

resource "aws_api_gateway_method_response" "search_country_city_street_get_200" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_web_api.id
  resource_id = aws_api_gateway_resource.search_country_city_street.id
  http_method = aws_api_gateway_method.search_country_city_street_get.http_method
  status_code = "200"

  response_models = {
    "application/json" = aws_api_gateway_model.list_properties_response_body.name
  }
}

###############################################
# Method Search/Country/City/street/number GET
##############################################

resource "aws_api_gateway_method" "search_country_city_street_number_get" {
  rest_api_id   = aws_api_gateway_rest_api.unicorn_web_api.id
  resource_id   = aws_api_gateway_resource.search_country_city_street_number.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.country" = true
    "method.request.path.city"    = true
    "method.request.path.street"  = true
    "method.request.path.number"  = true
  }
}

resource "aws_api_gateway_integration" "search_country_city_street_number_get" {
  rest_api_id             = aws_api_gateway_rest_api.unicorn_web_api.id
  resource_id             = aws_api_gateway_resource.search_country_city_street_number.id
  http_method             = aws_api_gateway_method.search_country_city_street_number_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_web_search_function.lambda_function_invoke_arn
  credentials             = module.iam_role_UnicornWebApiIntegrationRole.iam_role_arn
  passthrough_behavior    = "WHEN_NO_MATCH"
  content_handling        = "CONVERT_TO_TEXT"
}

resource "aws_api_gateway_method_response" "search_country_city_street_number_get_200" {
  rest_api_id = aws_api_gateway_rest_api.unicorn_web_api.id
  resource_id = aws_api_gateway_resource.search_country_city_street_number.id
  http_method = aws_api_gateway_method.search_country_city_street_number_get.http_method
  status_code = "200"

  response_models = {
    "application/json" = aws_api_gateway_model.list_properties_response_body.name
  }
}
#########
# Schemas
#########
resource "aws_api_gateway_model" "publication_evaluation_request_model" {
  rest_api_id  = aws_api_gateway_rest_api.unicorn_web_api.id
  name         = "PublicationEvaluationRequestModel"
  content_type = "application/json"
  schema       = <<EOF
{
  "type": "object",
  "required": ["property_id"],
  "properties": {
    "property_id": {
      "type": "string"
    }
  }
}
EOF
}

resource "aws_api_gateway_model" "publication_evaluation_response_model" {
  rest_api_id  = aws_api_gateway_rest_api.unicorn_web_api.id
  name         = "PublicationEvaluationResponseModel"
  content_type = "application/json"
  schema       = <<EOF
{
  "type": "object",
  "required": ["result"],
  "properties": {
    "result": {
      "type": "string"
    }
  }
}
EOF
}

resource "aws_api_gateway_model" "property_address" {
  rest_api_id  = aws_api_gateway_rest_api.unicorn_web_api.id
  name         = "PropertyAddress"
  content_type = "application/json"
  schema       = <<EOF
{
  "type": "object",
  "required": ["country", "city", "street", "number"],
  "properties": {
    "country": {
      "type": "string"
    },
    "city": {
      "type": "string"
    },
    "street": {
      "type": "string"
    },
    "number": {
      "type": "string"
    }
  }
}
EOF
}

resource "aws_api_gateway_model" "property_details" {
  rest_api_id  = aws_api_gateway_rest_api.unicorn_web_api.id
  name         = "PropertyDetails"
  content_type = "application/json"
  schema       = <<EOF
{
  "type": "object",
  "required": ["description", "images", "status"],
  "properties": {
    "description": {
      "type": "string"
    },
    "images": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "status": {
      "type": "string"
    }
  }
}
EOF
}

resource "aws_api_gateway_model" "property_offer" {
  rest_api_id  = aws_api_gateway_rest_api.unicorn_web_api.id
  name         = "PropertyOffer"
  content_type = "application/json"
  schema       = <<EOF
{
  "type": "object",
  "required": ["currency", "listprice", "contract", "status"],
  "properties": {
    "currency": {
      "type": "string"
    },
    "listprice": {
      "type": "string"
    },
    "contract": {
      "type": "string"
    },
    "status": {
      "type": "string"
    }
  }
}
EOF
}

resource "aws_api_gateway_model" "property" {
  rest_api_id  = aws_api_gateway_rest_api.unicorn_web_api.id
  name         = "Property"
  content_type = "application/json"
  depends_on = [
    aws_api_gateway_model.property_address,
    aws_api_gateway_model.property_details,
    aws_api_gateway_model.property_offer
  ]
  schema = <<EOF
{
  "allOf": [
    { "$ref": "https://apigateway.amazonaws.com/restapis/${aws_api_gateway_rest_api.unicorn_web_api.id}/models/PropertyAddress" },
    { "$ref": "https://apigateway.amazonaws.com/restapis/${aws_api_gateway_rest_api.unicorn_web_api.id}/models/PropertyDetails" },
    { "$ref": "https://apigateway.amazonaws.com/restapis/${aws_api_gateway_rest_api.unicorn_web_api.id}/models/PropertyOffer" },
    {
      "type": "object",
      "properties": {
        "status": {
          "type": "string"
        }
      }
    }
  ]
}
EOF
}

resource "aws_api_gateway_model" "list_properties_response_body" {
  rest_api_id  = aws_api_gateway_rest_api.unicorn_web_api.id
  name         = "ListPropertiesResponseBody"
  content_type = "application/json"
  depends_on = [
    aws_api_gateway_model.property_address,
    aws_api_gateway_model.property_offer
  ]
  schema = <<EOF
{
  "type": "array",
  "uniqueItems": true,
  "items": {
    "allOf": [
      { "$ref": "https://apigateway.amazonaws.com/restapis/${aws_api_gateway_rest_api.unicorn_web_api.id}/models/PropertyAddress" },
      { "$ref": "https://apigateway.amazonaws.com/restapis/${aws_api_gateway_rest_api.unicorn_web_api.id}/models/PropertyOffer" }
    ]
  }
}
EOF
}

resource "aws_api_gateway_model" "property_details_response_body" {
  rest_api_id  = aws_api_gateway_rest_api.unicorn_web_api.id
  name         = "PropertyDetailsResponseBody"
  content_type = "application/json"
  depends_on = [
    aws_api_gateway_model.property
  ]
  schema = <<EOF
{
  "type": "array",
  "uniqueItems": true,
  "items": {
    "$ref": "https://apigateway.amazonaws.com/restapis/${aws_api_gateway_rest_api.unicorn_web_api.id}/models/Property"
  }
}
EOF
}


############
# Validators
############
resource "aws_api_gateway_request_validator" "validate_body" {
  rest_api_id                 = aws_api_gateway_rest_api.unicorn_web_api.id
  name                        = "Validate body"
  validate_request_body       = true
  validate_request_parameters = false
}
