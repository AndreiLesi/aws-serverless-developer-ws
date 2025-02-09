resource "aws_ssm_parameter" "ImageBucket" {
  name  = "/uni-prop/prod/ImagesBucket"
  type  = "String"
  value = aws_s3_bucket.images.bucket
}

resource "aws_ssm_parameter" "ContractsNamespace" {
  name  = "/uni-prop/UnicornContractsNamespace"
  type  = "String"
  value = "unicorn.contracts"
}

resource "aws_ssm_parameter" "PropertiesNamespace" {
  name  = "/uni-prop/UnicornPropertiesNamespace"
  type  = "String"
  value = "unicorn.properties"
}

resource "aws_ssm_parameter" "WebNamespace" {
  name  = "/uni-prop/UnicornWebNamespace"
  type  = "String"
  value = "unicorn.web"
}