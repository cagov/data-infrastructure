##################################
#      AWS Secrets Manager       #
##################################

locals {
  snowflake_data = ["account", "user", "database", "warehouse", "role", "password"]

  jobs = ["test", "latest"]
}

data "aws_secretsmanager_secret" "snowflake_loader_secret" {
  for_each = toset(local.jobs)
  name     = var.snowflake_loader_secret[each.key]
}
