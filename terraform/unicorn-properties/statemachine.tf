module "sfn_properties_approval_state_machine" {
  source = "terraform-aws-modules/step-functions/aws"

  name                                   = "${var.project}-Properties-ApprovalStateMachine"
  cloudwatch_log_group_name              = "/aws/states/${var.project}-ApprovalStateMachine"
  cloudwatch_log_group_retention_in_days = 14
  type                                   = "STANDARD"

  definition = <<EOF
{
  "Comment": "A Hello World example of the Amazon States Language using Pass states",
  "StartAt": "Hello",
  "States": {
    "Hello": {
      "Type": "Pass",
      "Result": "Hello",
      "Next": "World"
    },
    "World": {
      "Type": "Pass",
      "Result": "World",
      "End": true
    }
  }
}
EOF

  logging_configuration = {
    include_execution_data = true
    level                  = "ALL"
  }

  service_integrations = {
    xray = {
      xray = true
    }

    dynamodb = {
      dynamodb = [aws_dynamodb_table.properties.arn]
    }

    lambda = {
      lambda = [
        module.lambda_properties_wait_for_contract_approval.lambda_function_arn,
        module.lambda_properties_contract_integrity_validator.lambda_function_arn,
        module.lambda_properties_contract_exist_check.lambda_function_arn
      ]
    }
  }

  attach_policy_statements = true
  number_of_policies       = 2
  policy_statements = {
    s3 = {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetObjectVersion",
        "s3:GetLifecycleConfiguration"
      ]
      resources = [
        "arn:aws:s3:::serverlessdeveloperexperience-images-bucket",
        "arn:aws:s3:::serverlessdeveloperexperience-images-bucket/*"
      ]
    },
    eventbridge = {
      effect    = "Allow"
      actions   = ["events:PutEvents"]
      resources = [module.eventbridge_properties_bus.eventbridge_bus_arn]
    },
    comprehend = {
        effect = "Allow",
        actions = [
            "comprehend:DetectEntities",
            "comprehend:DetectKeyPhrases",
            "comprehend:DetectDominantLanguage",
            "comprehend:DetectSentiment"
        ],
        resources = ["*"]
    },
    recognition = {
        effect = "Allow",
        actions = [
            "rekognition:DetectFaces",
            "rekognition:DetectLabels",
            "rekognition:DetectText"
        ],
        resources = ["*"]
    },
    cloudwatch_metrics = {
        effect = "Allow",
        actions = ["cloudwatch:PutMetricData"],
        resources = ["*"]
    },
  }
}
