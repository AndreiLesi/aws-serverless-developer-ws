# Log group Unicorn Contracts Catch All
resource "aws_cloudwatch_log_group" "UnicornContractsCatchAllLogGroup" {
  name              = "/aws/events/prod/${data.aws_ssm_parameter.ContractsNamespace.value}-catchall"
  retention_in_days = 14
}

# Log group DynamoDB Contracts Table Stream to Event Pipe Log Group
resource "aws_cloudwatch_log_group" "ContractsTableStreamToEventPipeLogGroup" {
  name              = "/aws/events/prod/${data.aws_ssm_parameter.ContractsNamespace.value}-ContractsTableStreamToEventPipe"
  retention_in_days = 14
}


# Log group API Gateway Unicorn Contracts
resource "aws_cloudwatch_log_group" "UnicornContractsApiLogGroup" {
  name              = "/aws/events/prod/${data.aws_ssm_parameter.ContractsNamespace.value}-Contracts-ApiGateway"
  retention_in_days = 14
}


# Log group Eventbridge Pipe
resource "aws_cloudwatch_log_group" "EventBridgePipe" {
  name              = "/aws/events/prod/${data.aws_ssm_parameter.ContractsNamespace.value}-Contracts-Pipe"
  retention_in_days = 14
}

