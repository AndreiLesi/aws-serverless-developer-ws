module "lambda_web_search_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name                           = "${var.project}-Web-SearchFunction"
  source_path                             = ["../src/search_service/property_search_function.py"]
  description                             = "Search Function used by the Web Client"
  handler                                 = "property_search_function.lambda_handler"
  runtime                                 = "python3.11"
  cloudwatch_logs_retention_in_days       = 14
  timeout                                 = 15
  memory_size                             = 128
  tracing_mode                            = "Active"
  attach_tracing_policy                   = true
  create_current_version_allowed_triggers = false

  attach_policy_statements = true
  policy_statements = {
    DynamoDBRead = {
      effect = "Allow"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:DescribeTable"
      ]
      resources = [aws_dynamodb_table.properties.arn]
    },
    APIGateway = {
      effect = "Allow"
      actions = [
        "apigateway:GET"
      ]
      resources = ["*"]
    }
  }

  layers = [
    "arn:aws:lambda:eu-central-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python311-x86_64:7"
  ]

  environment_variables = {
    DYNAMODB_TABLE               = aws_dynamodb_table.properties.name
    SERVICE_NAMESPACE            = data.aws_ssm_parameter.WebNamespace.value
    LOG_LEVEL                    = "INFO"
    POWERTOOLS_SERVICE_NAME      = data.aws_ssm_parameter.WebNamespace.value
    POWERTOOLS_LOGGER_LOG_EVENT  = "true"
    POWERTOOLS_METRICS_NAMESPACE = data.aws_ssm_parameter.WebNamespace.value
  }
}

module "lambda_request_approval_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name                           = "${var.project}-Web-RequestApproval"
  source_path                             = ["../src/approvals_service/request_approval_function.py"]
  description                             = "Search Function used by the Web Client"
  handler                                 = "request_approval_function.lambda_handler"
  runtime                                 = "python3.11"
  cloudwatch_logs_retention_in_days       = 14
  timeout                                 = 15
  memory_size                             = 128
  tracing_mode                            = "Active"
  attach_tracing_policy                   = true
  create_current_version_allowed_triggers = false

  attach_policy_statements = true
  policy_statements = {
    DynamoDBCrud = {
      effect = "Allow"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:Scan",
        "dynamodb:Query",
        "dynamodb:BatchGetItem",
        "dynamodb:DescribeTable"
      ]
      resources = [aws_dynamodb_table.properties.arn]
    },
    EventBridgePutEvent = {
      effect = "Allow"
      actions = [
        "events:PutEvents"
      ]
      resources = [module.eventbridge_unicorn_web_bus.eventbridge_bus_arn]
    },
    SQS = {
      effect = "Allow"
      actions = [
        "sqs:ReceiveMessage",
        "sqs:GetQueueAttributes",
        "sqs:DeleteMessage"
      ]
      resources = [module.sqs_UnicornWebIngestQueue.queue_arn]

    }
  }

  event_source_mapping = {
    sqs = {
      event_source_arn = module.sqs_UnicornWebIngestQueue.queue_arn
      batch_size       = 1
      scaling_config = {
        maximum_concurrency = 5
      }
    }
  }

  layers = [
    "arn:aws:lambda:eu-central-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python311-x86_64:7"
  ]

  environment_variables = {
    DYNAMODB_TABLE               = aws_dynamodb_table.properties.name
    EVENT_BUS = module.eventbridge_unicorn_web_bus.eventbridge_bus_name
    SERVICE_NAMESPACE            = data.aws_ssm_parameter.WebNamespace.value
    LOG_LEVEL                    = "INFO"
    POWERTOOLS_SERVICE_NAME      = data.aws_ssm_parameter.WebNamespace.value
    POWERTOOLS_LOGGER_LOG_EVENT  = "true"
    POWERTOOLS_METRICS_NAMESPACE = data.aws_ssm_parameter.WebNamespace.value
  }
}

module "lambda_publication_approved_event_handler" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "${var.project}-Web-PublicationApprovedEvent"
  source_path = [
    "../src/approvals_service/publication_approved_event_handler.py",
    {
      path          = "../src/approvals_service/schema",
      prefix_in_zip = "schema"
    }
  ]
  description                             = "Search Function used by the Web Client"
  handler                                 = "publication_approved_event_handler.lambda_handler"
  runtime                                 = "python3.11"
  cloudwatch_logs_retention_in_days       = 14
  timeout                                 = 15
  memory_size                             = 128
  tracing_mode                            = "Active"
  attach_tracing_policy                   = true
  create_current_version_allowed_triggers = false

  # attach_dead_letter_policy = true
  # dead_letter_target_arn    = module.sqs_UnicornWebIngestQueue.dead_letter_queue_arn

  attach_policy_statements = true
  policy_statements = {
    DynamoDBCrud = {
      effect = "Allow"
      actions = [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:BatchWriteItem"
      ]
      resources = [aws_dynamodb_table.properties.arn]
    }
  }

  allowed_triggers = {
    eventbridge = {
      principal  = "events.amazonaws.com"
      source_arn = module.eventbridge_unicorn_web_bus.eventbridge_rule_arns["TriggerLambdaOnPublicationApproved"]
    }
  }

  layers = [
    "arn:aws:lambda:eu-central-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python311-x86_64:7"
  ]

  environment_variables = {
    DYNAMODB_TABLE               = aws_dynamodb_table.properties.name
    SERVICE_NAMESPACE            = data.aws_ssm_parameter.WebNamespace.value
    LOG_LEVEL                    = "INFO"
    POWERTOOLS_SERVICE_NAME      = data.aws_ssm_parameter.WebNamespace.value
    POWERTOOLS_LOGGER_LOG_EVENT  = "true"
    POWERTOOLS_METRICS_NAMESPACE = data.aws_ssm_parameter.WebNamespace.value
  }
}