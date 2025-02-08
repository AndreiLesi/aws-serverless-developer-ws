#####################################################
## DLQ Eventbridge Events failed to deliver to Lambda
#####################################################
module "sqs_PropertiesEventBusRuleDLQ" {
  source                    = "terraform-aws-modules/sqs/aws"
  name                      = "${var.project}-Properties-EventBusRuleDLQ"
  message_retention_seconds = 1209600

  tags = {
    namespace = data.aws_ssm_parameter.PropertiesNamespace.value
  }
}

############################################
## DLQ Properties Service 
###########################################
module "sqs_PropertiesServiceDLQ" {
  source                    = "terraform-aws-modules/sqs/aws"
  name                      = "${var.project}-Properties-ServiceDLQ"
  message_retention_seconds = 1209600

  tags = {
    namespace = data.aws_ssm_parameter.PropertiesNamespace.value
  }
}