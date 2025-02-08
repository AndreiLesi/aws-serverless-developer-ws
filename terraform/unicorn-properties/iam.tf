# Eventbridge Pipe Read DynamoDB & Write EventBridge
module "iam_role_properties_subscription" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  trusted_role_services = ["events.amazonaws.com"]
  create_role           = true
  role_name             = "${var.project}-Properties-ContractsSubscription"
  role_requires_mfa     = false
  inline_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["events:PutEvents"]
      resources = [module.eventbridge_properties_bus.eventbridge_bus_arn]
    }
  ]
}