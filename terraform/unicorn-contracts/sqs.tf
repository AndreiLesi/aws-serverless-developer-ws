module "sqs_contracts_ingest" {
  source = "terraform-aws-modules/sqs/aws"

  name                       = "${var.project}-ContractsIngestQueue"
  message_retention_seconds  = 1209600
  visibility_timeout_seconds = 20
  create_dlq                 = true
  redrive_policy = {
    maxReceiveCount = 1
  }

  tags = {
    namespace = data.aws_ssm_parameter.ContractsNamespace.value
  }

  dlq_name = "${var.project}-ContractsIngestQueueDLQ"
  dlq_tags = {
    namespace = data.aws_ssm_parameter.ContractsNamespace.value
  }
}

############################################
## DLQ ContractsTableStream To Event Pipe
###########################################
module "sqs_ContractsTableStreamToEventPipeDLQ" {
  source                    = "terraform-aws-modules/sqs/aws"
  name                      = "${var.project}-ContractsTableStreamToEventPipeDLQ"
  message_retention_seconds = 1209600

  tags = {
    namespace = data.aws_ssm_parameter.ContractsNamespace.value
  }

}