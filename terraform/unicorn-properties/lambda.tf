
module "lambda_contract_status_changed_event_handler" {
  source = "terraform-aws-modules/lambda/aws"

  function_name                           = "${var.project}-Properties-ContractStatusChanged"
  source_path                             = [
    "../src/properties_service/contract_status_changed_event_handler.py",
    {
      path = "../src/properties_service/schema",
      prefix_in_zip = "schema"}
    ]
  description                             = "My awesome lambda function"
  handler                                 = "contract_status_changed_event_handler.lambda_handler"
  runtime                                 = "python3.11"
  cloudwatch_logs_retention_in_days       = 30
  timeout                                 = 15
  memory_size                             = 128
  tracing_mode                            = "Active"
  attach_tracing_policy                   = true
  create_current_version_allowed_triggers = false
  maximum_event_age_in_seconds            = 900
  maximum_retry_attempts                  = 5
  dead_letter_target_arn                  = module.sqs_PropertiesServiceDLQ.queue_arn
  attach_dead_letter_policy               = true

  attach_policy_statements = true
  policy_statements = {
    ContractsTableReadWrite = {
      effect = "Allow"
      actions = [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Scan",
        "dynamodb:Query",
        "dynamodb:GetItem"
      ]
      resources = [aws_dynamodb_table.contract-status.arn]
    }
  }

  allowed_triggers = {
    eventbridge = {
      principal  = "events.amazonaws.com"
      source_arn = module.eventbridge_properties_bus.eventbridge_rule_arns["properties.ContractStatusChanged"]
    }
  }

  layers = [
    "arn:aws:lambda:eu-central-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python311-x86_64:7"
  ]

  environment_variables = {
    CONTRACT_STATUS_TABLE        = aws_dynamodb_table.contract-status.name
    SERVICE_NAMESPACE            = data.aws_ssm_parameter.PropertiesNamespace.value
    LOG_LEVEL                    = "INFO"
    POWERTOOLS_SERVICE_NAME      = data.aws_ssm_parameter.PropertiesNamespace.value
    POWERTOOLS_LOGGER_LOG_EVENT  = "true"
    POWERTOOLS_METRICS_NAMESPACE = data.aws_ssm_parameter.PropertiesNamespace.value
  }
}

module "lambda_properties_approval_sync" {
  source = "terraform-aws-modules/lambda/aws"

  function_name                           = "${var.project}-Properties-ApprovalSync"
  source_path                             = "../src/properties_service/properties_approval_sync_function.py"
  description                             = "My awesome lambda function"
  handler                                 = "properties_approval_sync_function.lambda_handler"
  runtime                                 = "python3.11"
  cloudwatch_logs_retention_in_days       = 30
  timeout                                 = 15
  memory_size                             = 128
  tracing_mode                            = "Active"
  attach_tracing_policy                   = true
  create_current_version_allowed_triggers = false
  maximum_event_age_in_seconds            = 900
  maximum_retry_attempts                  = 5
  dead_letter_target_arn                  = module.sqs_PropertiesServiceDLQ.queue_arn
  attach_dead_letter_policy               = true

  attach_policy_statements = true
  policy_statements = {
    DynamoDBRead = {
      effect = "Allow"
      actions = [
        "dynamodb:BatchGetItem",
        "dynamodb:Describe*",
        "dynamodb:List*",
        "dynamodb:GetAbacStatus",
        "dynamodb:GetItem",
        "dynamodb:GetResourcePolicy",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:PartiQLSelect",
      ]
      resources = [aws_dynamodb_table.contract-status.arn]
    },
    DynamoDBStreamsRead = {
      effect = "Allow"
      actions = [
        "dynamodb:DescribeStream",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:ListStreams",
      ]
      resources = [aws_dynamodb_table.contract-status.stream_arn]
    }
    StateMachineTaskSuccess = {
      effect = "Allow"
      actions = [
        "states:SendTaskSuccess",     
      ]
      resources = [module.sfn_properties_approval_state_machine.state_machine_arn]
    }
  }

  event_source_mapping = {
    dynamodb = {
      event_source_arn       = aws_dynamodb_table.contract-status.stream_arn
      starting_position      = "LATEST"
      batch_size             = 100
      maximum_retry_attempts = 3
      starting_position      = "TRIM_HORIZON"
      enabled                = true
      destination_config = {
        on_failure = {
          destination_arn = module.sqs_PropertiesServiceDLQ.queue_arn
        }
      }
    }
  }

  layers = [
    "arn:aws:lambda:eu-central-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python311-x86_64:7"
  ]

  environment_variables = {
    CONTRACT_STATUS_TABLE        = aws_dynamodb_table.contract-status.name
    SERVICE_NAMESPACE            = data.aws_ssm_parameter.PropertiesNamespace.value
    LOG_LEVEL                    = "INFO"
    POWERTOOLS_SERVICE_NAME      = data.aws_ssm_parameter.PropertiesNamespace.value
    POWERTOOLS_LOGGER_LOG_EVENT  = "true"
    POWERTOOLS_METRICS_NAMESPACE = data.aws_ssm_parameter.PropertiesNamespace.value
  }
}

module "lambda_properties_contract_exist_check" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "${var.project}-Properties-ContractExistCheck"
  source_path = [
    "../src/properties_service/contract_exists_checker_function.py",
    "../src/properties_service/exceptions.py"
  ]
  description                             = "My awesome lambda function"
  handler                                 = "contract_exists_checker_function.lambda_handler"
  runtime                                 = "python3.11"
  cloudwatch_logs_retention_in_days       = 30
  timeout                                 = 15
  memory_size                             = 128
  tracing_mode                            = "Active"
  attach_tracing_policy                   = true
  create_current_version_allowed_triggers = false
  maximum_event_age_in_seconds            = 900
  maximum_retry_attempts                  = 5
  dead_letter_target_arn                  = module.sqs_PropertiesServiceDLQ.queue_arn
  attach_dead_letter_policy               = true

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
      resources = [aws_dynamodb_table.contract-status.arn]
    }
  }

  layers = [
    "arn:aws:lambda:eu-central-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python311-x86_64:7"
  ]

  environment_variables = {
    CONTRACT_STATUS_TABLE        = aws_dynamodb_table.contract-status.name
    SERVICE_NAMESPACE            = data.aws_ssm_parameter.PropertiesNamespace.value
    LOG_LEVEL                    = "INFO"
    POWERTOOLS_SERVICE_NAME      = data.aws_ssm_parameter.PropertiesNamespace.value
    POWERTOOLS_LOGGER_LOG_EVENT  = "true"
    POWERTOOLS_METRICS_NAMESPACE = data.aws_ssm_parameter.PropertiesNamespace.value
  }
}

module "lambda_properties_contract_integrity_validator" {
  source = "terraform-aws-modules/lambda/aws"

  function_name                           = "${var.project}-Properties-ContractIntegrityVal"
  source_path                             = "../src/properties_service/content_integrity_validator_function.py"
  description                             = "My awesome lambda function"
  handler                                 = "content_integrity_validator_function.lambda_handler"
  runtime                                 = "python3.11"
  cloudwatch_logs_retention_in_days       = 30
  timeout                                 = 15
  memory_size                             = 128
  tracing_mode                            = "Active"
  attach_tracing_policy                   = true
  create_current_version_allowed_triggers = false
  maximum_event_age_in_seconds            = 900
  maximum_retry_attempts                  = 5
  dead_letter_target_arn                  = module.sqs_PropertiesServiceDLQ.queue_arn
  attach_dead_letter_policy               = true

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
      resources = [aws_dynamodb_table.contract-status.arn]
    }
  }

  layers = [
    "arn:aws:lambda:eu-central-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python311-x86_64:7"
  ]

  environment_variables = {
    CONTRACT_STATUS_TABLE        = aws_dynamodb_table.contract-status.name
    SERVICE_NAMESPACE            = data.aws_ssm_parameter.PropertiesNamespace.value
    LOG_LEVEL                    = "INFO"
    POWERTOOLS_SERVICE_NAME      = data.aws_ssm_parameter.PropertiesNamespace.value
    POWERTOOLS_LOGGER_LOG_EVENT  = "true"
    POWERTOOLS_METRICS_NAMESPACE = data.aws_ssm_parameter.PropertiesNamespace.value
  }
}

module "lambda_properties_wait_for_contract_approval" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "${var.project}-Properties-WaitForContractApproval"
  source_path = [
    "../src/properties_service/wait_for_contract_approval_function.py",
    "../src/properties_service/exceptions.py"
  ]
  description                             = "My awesome lambda function"
  handler                                 = "wait_for_contract_approval_function.lambda_handler"
  runtime                                 = "python3.11"
  cloudwatch_logs_retention_in_days       = 30
  timeout                                 = 15
  memory_size                             = 128
  tracing_mode                            = "Active"
  attach_tracing_policy                   = true
  create_current_version_allowed_triggers = false
  maximum_event_age_in_seconds            = 900
  maximum_retry_attempts                  = 5
  dead_letter_target_arn                  = module.sqs_PropertiesServiceDLQ.queue_arn
  attach_dead_letter_policy               = true

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
      resources = [aws_dynamodb_table.contract-status.arn]
    }
  }

  layers = [
    "arn:aws:lambda:eu-central-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python311-x86_64:7"
  ]

  environment_variables = {
    CONTRACT_STATUS_TABLE        = aws_dynamodb_table.contract-status.name
    SERVICE_NAMESPACE            = data.aws_ssm_parameter.PropertiesNamespace.value
    LOG_LEVEL                    = "INFO"
    POWERTOOLS_SERVICE_NAME      = data.aws_ssm_parameter.PropertiesNamespace.value
    POWERTOOLS_LOGGER_LOG_EVENT  = "true"
    POWERTOOLS_METRICS_NAMESPACE = data.aws_ssm_parameter.PropertiesNamespace.value
  }
}
