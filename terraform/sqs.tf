module "sqs_contracts_ingest" {
  source = "terraform-aws-modules/sqs/aws"

  name                       = "${local.project}-ContractsIngestQueue"
  message_retention_seconds  = 1209600
  visibility_timeout_seconds = 20
  create_dlq                 = true
  redrive_policy = {
    maxReceiveCount = 1
  }

  tags = {
    namespace = aws_ssm_parameter.ContractsNamespace.value
  }

  dlq_name = "${local.project}-ContractsIngestQueueDLQ"
  dlq_tags = {
    namespace = aws_ssm_parameter.ContractsNamespace.value
  }
}

############################################
## DLQ ContractsTableStream To Event Pipe
###########################################
module "sqs_ContractsTableStreamToEventPipeDLQ" {
  source                    = "terraform-aws-modules/sqs/aws"
  name                      = "${local.project}-ContractsTableStreamToEventPipeDLQ"
  message_retention_seconds = 1209600

  tags = {
    namespace = aws_ssm_parameter.ContractsNamespace.value
  }

}