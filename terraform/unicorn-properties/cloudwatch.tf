# Log group Unicorn Properties Catch All
resource "aws_cloudwatch_log_group" "UnicornPropertiesCatchAllLogGroup" {
  name              = "/aws/events/prod/${data.aws_ssm_parameter.PropertiesNamespace.value}-catchall"
  retention_in_days = 14
}
