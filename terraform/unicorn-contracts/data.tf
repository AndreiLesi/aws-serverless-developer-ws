data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_ssm_parameter" "ContractsNamespace" {
  name = "/uni-prop/UnicornContractsNamespace"
}
data "aws_ssm_parameter" "PropertiesNamespace" {
  name = "/uni-prop/UnicornPropertiesNamespace"
}
data "aws_ssm_parameter" "WebNamespace" {
  name = "/uni-prop/UnicornWebNamespace"
}

data "aws_s3_bucket" "images" {
  bucket = "${lower(var.project)}-images-bucket"
}
