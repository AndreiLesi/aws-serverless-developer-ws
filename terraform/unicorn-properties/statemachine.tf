module "sfn_properties_approval_state_machine" {
  source = "terraform-aws-modules/step-functions/aws"

  name                                   = "${var.project}-Properties-ApprovalStateMachine"
  cloudwatch_log_group_name              = "/aws/states/${var.project}-ApprovalStateMachine"
  cloudwatch_log_group_retention_in_days = 14
  type                                   = "STANDARD"

  definition = <<EOF
{
  "Comment": "A Hello World example of the Amazon States Language using Pass states",
  "StartAt": "VerifyContractExists",
  "States": {
    "VerifyContractExists": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${module.lambda_properties_contract_exist_check.lambda_function_arn}",
        "Payload": {
          "Input.$": "$"
        }
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2,
          "JitterStrategy": "FULL"
        }
      ],
      "InputPath": "$.detail",
      "ResultPath": "$.contract_exists_check",
      "Catch": [
        {
          "ErrorEquals": [
            "ContractStatusNotFoundException"
          ],
          "Next": "Fail"
        }
      ],
      "Next": "CheckImageIntegrity"
    },
    "CheckImageIntegrity": {
      "Type": "Map",
      "ItemProcessor": {
        "ProcessorConfig": {
          "Mode": "INLINE"
        },
        "StartAt": "DetectModerationLabels",
        "States": {
          "DetectModerationLabels": {
            "Type": "Task",
            "Parameters": {
              "Image": {
                "S3Object": {
                  "Bucket": "${lower(var.project)}-images-bucket",
                  "Name.$": "$.ImageName"
                }
              }
            },
            "Resource": "arn:aws:states:::aws-sdk:rekognition:detectModerationLabels",
            "End": true
          }
        }
      },
      "Next": "CheckDescriptionSentiment",
      "ItemsPath": "$.detail.images",
      "ItemSelector": {
        "ImageName.$": "$$.Map.Item.Value"
      },
      "ResultPath": "$.imageModerations"
    },
    "CheckDescriptionSentiment": {
      "Type": "Task",
      "Parameters": {
        "LanguageCode": "en",
        "Text.$": "$.detail.description"
      },
      "Resource": "arn:aws:states:::aws-sdk:comprehend:detectSentiment",
      "Next": "ValidateContentIntegrity",
      "ResultPath": "$.contentSentiment"
    },
    "ValidateContentIntegrity": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "${module.lambda_properties_contract_integrity_validator.lambda_function_arn}"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2,
          "JitterStrategy": "FULL"
        }
      ],
      "Next": "IsContentSafe",
      "ResultSelector": {
        "validation_result.$": "$.Payload.validation_result"
      },
      "ResultPath": "$.validation_check"
    },
    "IsContentSafe": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.validation_check.validation_result",
          "StringEquals": "FAIL",
          "Next": "PublishPropertyPublicationRejected"
        },
        {
          "Variable": "$.validation_check.validation_result",
          "StringEquals": "PASS",
          "Next": "WaitForContractApproval"
        }
      ]
    },
    "PublishPropertyPublicationRejected": {
      "Type": "Task",
      "Resource": "arn:aws:states:::events:putEvents",
      "Parameters": {
        "Entries": [
          {
            "Detail": {
              "property_id.$": "$.detail.property_id",
              "evaluation_result": "DECLINED"
            },
            "DetailType": "PublicationEvaluationCompleted",
            "EventBusName": "${module.eventbridge_properties_bus.eventbridge_bus_name}",
            "Source": "${data.aws_ssm_parameter.PropertiesNamespace.value}"
          }
        ]
      },
      "Next": "Declined"
    },
    "WaitForContractApproval": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke.waitForTaskToken",
      "Parameters": {
        "FunctionName": "${module.lambda_properties_wait_for_contract_approval.lambda_function_arn}",
        "Payload": {
          "Input.$": "$",
          "TaskToken.$": "$$.Task.Token"
        }
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2,
          "JitterStrategy": "FULL"
        }
      ],
      "InputPath": "$.detail",
      "ResultPath": "$.status_check",
      "Next": "PublishPropertyPublicationApproved"
    },
    "PublishPropertyPublicationApproved": {
      "Type": "Task",
      "Resource": "arn:aws:states:::events:putEvents",
      "Parameters": {
        "Entries": [
          {
            "Detail": {
              "property_id.$": "$.detail.property_id",
              "evaluation_result": "APPROVED"
            },
            "DetailType": "PublicationEvaluationCompleted",
            "EventBusName": "${module.eventbridge_properties_bus.eventbridge_bus_name}",
            "Source": "${data.aws_ssm_parameter.PropertiesNamespace.value}"
          }
        ]
      },
      "Next": "Success"
    },
    "Declined": {
      "Type": "Succeed"
    },
    "Success": {
      "Type": "Succeed"
    },
    "Fail": {
      "Type": "Fail"
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
      dynamodb = [aws_dynamodb_table.contract-status.arn]
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
          "comprehend:BatchDetectKeyPhrases",
          "comprehend:DetectDominantLanguage",
          "comprehend:DetectEntities",
          "comprehend:BatchDetectEntities",
          "comprehend:DetectKeyPhrases",
          "comprehend:DetectSentiment",
          "comprehend:BatchDetectDominantLanguage",
          "comprehend:BatchDetectSentiment"
        ],
        resources = ["*"]
    },
    recognition = {
        effect = "Allow",
        actions = [
            "rekognition:DetectFaces",
            "rekognition:DetectLabels",
            "rekognition:DetectText",
            "rekognition:DetectModerationLabels"
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
