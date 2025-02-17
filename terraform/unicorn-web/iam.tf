# API GATEWAY - UNICORN WEB ACCOUNT CONFIG ROLE
module "iam_role_UnicornWebApiGwAccountConfigRole" {
  source                  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  trusted_role_services   = ["apigateway.amazonaws.com"]
  create_role             = true
  role_name               = "${var.project}-UnicornWebApiGwAccountConfigRole"
  role_requires_mfa       = false
  custom_role_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"]
}

# Unicorn Web API Gateway Integration Role
module "iam_role_UnicornWebApiIntegrationRole" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  trusted_role_services = ["apigateway.amazonaws.com"]
  create_role           = true
  role_name             = "${var.project}-UnicornWebApiIntegrationRole"
  role_requires_mfa     = false
  inline_policy_statements = [
    {
      effect = "Allow"
      actions = [
        "sqs:SendMessage",
        "sqs:GetQueueUrl",
      ]
      resources = [module.sqs_UnicornWebIngestQueue.queue_arn]
    },
    {
      effect    = "Allow"
      actions   = ["lambda:InvokeFunction"]
      resources = [module.lambda_web_search_function.lambda_function_arn]
    }
  ]
}

# Eventbridge Pipe Read DynamoDB & Write EventBridge
module "iam_role_web_properties_subscription" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  trusted_role_services = ["events.amazonaws.com"]
  create_role           = true
  role_name             = "${var.project}-Web-PropertiesSubscription"
  role_requires_mfa     = false
  inline_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["events:PutEvents"]
      resources = [module.eventbridge_unicorn_web_bus.eventbridge_bus_arn]
    }
  ]
}
# Eventbridge Pipe Read DynamoDB & Write EventBridge
module "iam_role_web_to_properties_push" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  trusted_role_services = ["events.amazonaws.com"]
  create_role           = true
  role_name             = "${var.project}-Web-PushEventToPropertiesBus"
  role_requires_mfa     = false
  inline_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["events:PutEvents"]
      resources = [data.aws_cloudwatch_event_bus.properties.arn]
    }
  ]
}