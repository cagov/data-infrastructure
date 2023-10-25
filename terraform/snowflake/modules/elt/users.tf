######################################
#      Service Accounts/Users        #
######################################

resource "snowflake_user" "dbt" {
  provider = snowflake.useradmin
  name     = "DBT_CLOUD_SVC_USER_${var.environment}"
  comment  = "Service user for dbt Cloud"

  default_warehouse = module.transforming["XS"].name
  default_role      = snowflake_role.transformer.name

  must_change_password = false
}


resource "snowflake_user" "airflow" {
  provider = snowflake.useradmin
  name     = "MWAA_SVC_USER_${var.environment}"
  comment  = "Service user for Airflow"

  default_warehouse = module.loading["XS"].name
  default_role      = snowflake_role.loader.name

  must_change_password = false
}

resource "snowflake_user" "fivetran" {
  provider = snowflake.useradmin
  name     = "FIVETRAN_SVC_USER_${var.environment}"
  comment  = "Service user for Fivetran"

  default_warehouse = module.loading["XS"].name
  default_role      = snowflake_role.loader.name

  must_change_password = false
}

resource "snowflake_user" "github_ci" {
  provider = snowflake.useradmin
  name     = "GITHUB_ACTIONS_SVC_USER_${var.environment}"
  comment  = "Service user for GitHub CI"

  default_warehouse = module.reporting["XS"].name
  default_role      = snowflake_role.reader.name

  must_change_password = false
}

resource "snowflake_user" "sentinel" {
  provider = snowflake.useradmin
  name     = "SENTINEL_SVC_USER_${var.environment}"
  comment  = "Service user for Sentinel"

  default_warehouse = module.logging.name
  default_role      = snowflake_role.logger.name

  must_change_password = false
}

######################################
#            Role Grants             #
######################################

resource "snowflake_role_grants" "transformer_to_dbt" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.transformer.name
  enable_multiple_grants = true
  users                  = [snowflake_user.dbt.name]
}

resource "snowflake_role_grants" "loader_to_airflow" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.loader.name
  enable_multiple_grants = true
  users                  = [snowflake_user.airflow.name]
}

resource "snowflake_role_grants" "loader_to_fivetran" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.loader.name
  enable_multiple_grants = true
  users                  = [snowflake_user.fivetran.name]
}

resource "snowflake_role_grants" "reader_to_github_ci" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.reader.name
  enable_multiple_grants = true
  users                  = [snowflake_user.github_ci.name]
}

resource "snowflake_role_grants" "logger_to_sentinel" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.logger.name
  enable_multiple_grants = true
  users                  = [snowflake_user.sentinel.name]
}

######################################
#          Privilege Grants          #
######################################

# Imported privileges for logging
resource "snowflake_database_grant" "this" {
  provider               = snowflake.accountadmin
  database_name          = "SNOWFLAKE"
  privilege              = "IMPORTED PRIVILEGES"
  enable_multiple_grants = true
  roles                  = [snowflake_role.logger.name]
}
