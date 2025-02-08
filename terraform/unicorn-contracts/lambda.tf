module "lambda_image_upload" {
  source = "terraform-aws-modules/lambda/aws"

  function_name                     = "${var.project}-ImageUpload"
  source_path                       = "../src/image/upload_image.py"
  description                       = "My awesome lambda function"
  handler                           = "upload_image.lambda_handler"
  runtime                           = "python3.11"
  cloudwatch_logs_retention_in_days = 30
  timeout                           = 300
  memory_size                       = 128

  environment_variables = {
    DESTINATION_BUCKET = aws_s3_bucket.images.bucket
  }

  attach_policy_statements = true
  policy_statements = {
    S3 = {
      effect = "Allow"
      actions = [
        "s3:ListBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:DeleteBucket"
      ]
      resources = [
        "${aws_s3_bucket.images.arn}",
        "${aws_s3_bucket.images.arn}/*",
      ]
    }
  }
}

module "lambda_contract_event_handler" {
  source = "terraform-aws-modules/lambda/aws"

  function_name                     = "${var.project}-Contract-EventHandler"
  source_path                       = "../src/contracts_service/"
  description                       = "My awesome lambda function"
  handler                           = "contract_event_handler.lambda_handler"
  runtime                           = "python3.11"
  cloudwatch_logs_retention_in_days = 30
  timeout                           = 5
  memory_size                       = 128
  tracing_mode                      = "Active"
  attach_tracing_policy             = true

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
      resources = [aws_dynamodb_table.contracts.arn]
    }
  }

  event_source_mapping = {
    sqs = {
      event_source_arn = module.sqs_contracts_ingest.queue_arn
      batch_size       = 1
      #   function_response_message = "Success"
      scaling_config = {
        maximum_concurrency = 5
      }
    }
  }

  attach_policy_json = true
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SQSContractsIngest"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          module.sqs_contracts_ingest.queue_arn
        ]
      }
    ]
  })

  layers = [
    "arn:aws:lambda:eu-central-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python311-x86_64:7"
  ]

  environment_variables = {
    DYNAMODB_TABLE               = aws_dynamodb_table.contracts.name
    SERVICE_NAMESPACE            = aws_ssm_parameter.ContractsNamespace.value
    LOG_LEVEL                    = "INFO"
    POWERTOOLS_SERVICE_NAME      = aws_ssm_parameter.ContractsNamespace.value
    POWERTOOLS_LOGGER_LOG_EVENT  = "true"
    POWERTOOLS_METRICS_NAMESPACE = aws_ssm_parameter.ContractsNamespace.value
  }
}
