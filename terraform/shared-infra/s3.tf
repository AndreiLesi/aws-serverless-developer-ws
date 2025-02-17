resource "aws_s3_bucket" "images" {
  bucket = "${lower(var.project)}-images-bucket"
  force_destroy = true
}