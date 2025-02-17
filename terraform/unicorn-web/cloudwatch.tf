# Log group Unicorn Web Catch All
resource "aws_cloudwatch_log_group" "UnicornWebCatchAllLogGroup" {
  name              = "/aws/events/prod/${data.aws_ssm_parameter.WebNamespace.value}-catchall"
  retention_in_days = 14
}
# Log group Unicorn Web API Gateway
resource "aws_cloudwatch_log_group" "UnicornWebApiGateway" {
  name              = "/aws/apigateway/prod/UnicornWebApiLogGroup"
  retention_in_days = 14
}
