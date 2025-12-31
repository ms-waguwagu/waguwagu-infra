data "aws_cloudformation_export" "loki_bucket_name" {
  name = "t3-wagu-loki-s3-bucket"
}

data "aws_cloudformation_export" "loki_bucket_arn" {
  name = "t3-wagu-loki-s3-bucket-arn"
}
