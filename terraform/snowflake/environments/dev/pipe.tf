variable "storage_aws_role_arn" {
  type = string
}

variable "storage_allowed_location" {
  type = string
}
resource "snowflake_storage_integration" "this" {
  provider                  = snowflake.accountadmin
  name                      = "storage"
  type                      = "EXTERNAL_STAGE"
  storage_provider          = "S3"
  storage_aws_role_arn      = var.storage_aws_role_arn
  storage_allowed_locations = [var.storage_allowed_location]
}

output "snowpipe" {
  value = {
    storage_aws_external_id  = snowflake_storage_integration.this.storage_aws_external_id
    storage_aws_iam_user_arn = snowflake_storage_integration.this.storage_aws_iam_user_arn
  }
}
