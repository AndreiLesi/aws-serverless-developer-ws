resource "aws_dynamodb_table" "contracts" {
  name             = "${var.project}-Contracts"
  hash_key         = "property_id"
  billing_mode     = "PAY_PER_REQUEST"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  attribute {
    name = "property_id"
    type = "S"
  }
  tags = {
    stage     = "Prod"
    namespace = aws_ssm_parameter.ContractsNamespace.value
  }
}