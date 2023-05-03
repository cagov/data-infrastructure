output "state" {
  description = "Resources from terraform-state"
  value = {
    bucket_arn = aws_s3_bucket.terraform_state.arn
    dynamo_arn = aws_dynamodb_table.terraform_state_lock.arn
  }
}
