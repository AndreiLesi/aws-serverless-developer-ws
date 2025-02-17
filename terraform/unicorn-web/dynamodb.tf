resource "aws_dynamodb_table" "properties" {
  name         = "${var.project}-Properties"
  hash_key     = "PK"
  range_key    = "SK"
  billing_mode = "PAY_PER_REQUEST"
  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
  tags = {
    stage     = "Prod"
    namespace = data.aws_ssm_parameter.WebNamespace.value
  }
}