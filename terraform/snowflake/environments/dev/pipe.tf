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

resource "snowflake_stage" "this" {
  provider            = snowflake.accountadmin
  name                = "TEST_STAGE"
  url                 = var.storage_allowed_location
  database            = "RAW_${var.environment}"
  schema              = "TEST_PIPE"
  storage_integration = snowflake_storage_integration.this.name
}

resource "snowflake_stage_grant" "this" {
  provider      = snowflake.securityadmin
  database_name = snowflake_stage.this.database
  schema_name   = snowflake_stage.this.schema
  roles         = ["LOADER_${var.environment}"]
  privilege     = "OWNERSHIP"
  stage_name    = snowflake_stage.this.name
}

resource "snowflake_pipe" "pipe" {
  provider = snowflake.accountadmin # Fix with an appropriate access role.
  database = "RAW_${var.environment}"
  schema   = "TEST_PIPE"
  name     = "TEST_PIPE"

  #https://github.com/Snowflake-Labs/terraform-provider-snowflake/issues/533#issuecomment-1171442286
  copy_statement = "copy into RAW_${var.environment}.TEST_PIPE.TEST_TABLE from @${snowflake_stage.this.database}.${snowflake_stage.this.schema}.${snowflake_stage.this.name} file_format = (type='CSV', SKIP_HEADER=1);"
  auto_ingest    = true
}
