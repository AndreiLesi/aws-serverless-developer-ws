module "iam_role_ContractsTableStreamToEventPipe" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  trusted_role_services = ["pipes.amazonaws.com"]
  trust_policy_conditions = [
    {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  ]
  create_role       = true
  role_name         = "${var.project}-ContractsStreamToEventPipe"
  role_requires_mfa = false
  inline_policy_statements = [
    {
      effect = "Allow"
      actions = [
        "dynamodb:ListStreams"
      ]
      resources = ["*"]
    },
    {
      effect = "Allow"
      actions = [
        "dynamodb:DescribeStream",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:ListStreams"
      ]
      resources = [aws_dynamodb_table.contracts.stream_arn]
    },
    {
      effect = "Allow"
      actions = [
        "events:PutEvents"
      ]
      resources = [module.eventbridge_contracts_bus.eventbridge_bus_arn]
    },
    {
      effect = "Allow"
      actions = [
        "sqs:SendMessage"
      ]
      resources = [module.sqs_ContractsTableStreamToEventPipeDLQ.queue_arn]
    }
  ]
}

# API GATEWAY ACCOUNT CONFIG ROLE
module "iam_role_ApiGatewayAccountConfigRole" {
  source                  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  trusted_role_services   = ["apigateway.amazonaws.com"]
  create_role             = true
  role_name               = "${var.project}-ApiGatewayAccountConfigRole"
  role_requires_mfa       = false
  custom_role_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"]
}

# APIGATEWAY write to SQS Queue
module "iam_role_UnicornContractsApiIntegrationRole" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  trusted_role_services = ["apigateway.amazonaws.com"]
  create_role           = true
  role_name             = "${var.project}-UnicornContractsApiIntegrationRole"
  role_requires_mfa     = false
  inline_policy_statements = [
    {
      effect = "Allow"
      actions = [
        "sqs:SendMEssage",
        "sqs:GetQueueUrl"
      ]
      resources = [module.sqs_contracts_ingest.queue_arn]
    }
  ]
}

# Eventbridge Pipe Read DynamoDB & Write EventBridge
module "iam_role_EventBridgePipe" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  trusted_role_services = ["pipes.amazonaws.com"]
  create_role           = true
  role_name             = "${var.project}-EventBridgePipe-Contracts-Role"
  role_requires_mfa     = false
  inline_policy_statements = [
    {
      effect = "Allow"
      actions = [
        "dynamodb:DescribeStream",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:ListStreams"
      ]
      resources = [aws_dynamodb_table.contracts.stream_arn]
    },
    {
      effect    = "Allow"
      actions   = ["events:PutEvents"]
      resources = [module.eventbridge_contracts_bus.eventbridge_bus_arn]
    }
  ]
}