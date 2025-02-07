resource "aws_s3_bucket" "images" {
  bucket = "${lower(local.project)}-images-bucket"
}