#####################################################
## API Gateway Ingestion Queue & DLQ
#####################################################
module "sqs_UnicornWebIngestQueue" {
  source                     = "terraform-aws-modules/sqs/aws"
  name                       = "${var.project}-Web-UnicornWebIngestQueue"
  message_retention_seconds  = 1209600
  visibility_timeout_seconds = 20

  create_dlq = true
  dlq_name   = "${var.project}-Web-UnicornWebIngestDLQ"
  redrive_policy = {
    maxReceiveCount = 1
  }
  dlq_tags = {
    namespace = data.aws_ssm_parameter.WebNamespace.value
  }

  tags = {
    namespace = data.aws_ssm_parameter.WebNamespace.value
  }
}