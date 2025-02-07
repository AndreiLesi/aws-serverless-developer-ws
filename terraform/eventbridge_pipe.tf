resource "aws_pipes_pipe" "this" {
  name          = "${local.project}-ContractsPipe"
  role_arn      = module.iam_role_EventBridgePipe.iam_role_arn
  desired_state = "RUNNING"

  source = aws_dynamodb_table.contracts.stream_arn
  target = module.eventbridge_contracts_bus.eventbridge_bus_arn

  source_parameters {
    filter_criteria {
      filter {
        pattern = jsonencode({
          eventName = ["INSERT", "MODIFY"]
          dynamodb = {
            NewImage = {
              contract_status = {
                S = ["DRAFT", "APPROVED"]
              }
            }
          }
        })
      }
    }

    dynamodb_stream_parameters {
      batch_size                    = 1
      maximum_record_age_in_seconds = -1
      maximum_retry_attempts        = -1
      starting_position             = "LATEST"
    }
  }

  target_parameters {
    input_template = <<EOF
{
  "contract_last_modified_on" : "<$.dynamodb.NewImage.contract_last_modified_on.S>",
  "contract_id"               : "<$.dynamodb.NewImage.contract_id.S>",
  "contract_status"           : "<$.dynamodb.NewImage.contract_status.S>",
  "property_id"               : "<$.dynamodb.NewImage.property_id.S>"
}
EOF

    eventbridge_event_bus_parameters {
      detail_type = "ContractStatusChanged"
      source      = "unicorn.contracts"
    }
  }

  log_configuration {
    cloudwatch_logs_log_destination {
      log_group_arn = aws_cloudwatch_log_group.EventBridgePipe.arn
    }
    level = "INFO"
  }

  depends_on = [
    module.eventbridge_contracts_bus,
    module.iam_role_EventBridgePipe
  ]
}

