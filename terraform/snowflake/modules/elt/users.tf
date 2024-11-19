######################################
#      Service Accounts/Users        #
######################################

resource "snowflake_user" "dbt" {
  provider = snowflake.useradmin
  name     = "DBT_CLOUD_SVC_USER_${var.environment}"
  comment  = "Service user for dbt Cloud"
  lifecycle {
    ignore_changes = [rsa_public_key]
  }

  default_warehouse = module.transforming["XS"].name
  default_role      = snowflake_account_role.transformer.name

  must_change_password = false
}


resource "snowflake_user" "airflow" {
  provider = snowflake.useradmin
  name     = "MWAA_SVC_USER_${var.environment}"
  comment  = "Service user for Airflow"
  lifecycle {
    ignore_changes = [rsa_public_key]
  }

  default_warehouse = module.loading["XS"].name
  default_role      = snowflake_account_role.loader.name

  must_change_password = false
}

resource "snowflake_user" "fivetran" {
  provider = snowflake.useradmin
  name     = "FIVETRAN_SVC_USER_${var.environment}"
  comment  = "Service user for Fivetran"
  lifecycle {
    ignore_changes = [rsa_public_key]
  }

  default_warehouse = module.loading["XS"].name
  default_role      = snowflake_account_role.loader.name

  must_change_password = false
}

resource "snowflake_user" "github_ci" {
  provider = snowflake.useradmin
  name     = "GITHUB_ACTIONS_SVC_USER_${var.environment}"
  comment  = "Service user for GitHub CI"
  lifecycle {
    ignore_changes = [rsa_public_key]
  }

  default_warehouse = module.reporting["XS"].name
  default_role      = snowflake_account_role.reader.name

  must_change_password = false
}

resource "snowflake_user" "sentinel" {
  provider = snowflake.useradmin
  name     = "SENTINEL_SVC_USER_${var.environment}"
  comment  = "Service user for Sentinel"
  lifecycle {
    ignore_changes = [rsa_public_key]
  }

  default_warehouse = module.logging.name
  default_role      = snowflake_account_role.logger.name

  must_change_password = false
}

######################################
#            Role Grants             #
######################################

resource "snowflake_grant_account_role" "transformer_to_dbt" {
  provider  = snowflake.useradmin
  role_name = snowflake_account_role.transformer.name
  user_name = snowflake_user.dbt.name
}

resource "snowflake_grant_account_role" "loader_to_airflow" {
  provider  = snowflake.useradmin
  role_name = snowflake_account_role.loader.name
  user_name = snowflake_user.airflow.name
}

resource "snowflake_grant_account_role" "loader_to_fivetran" {
  provider  = snowflake.useradmin
  role_name = snowflake_account_role.loader.name
  user_name = snowflake_user.fivetran.name
}

resource "snowflake_grant_account_role" "reader_to_github_ci" {
  provider  = snowflake.useradmin
  role_name = snowflake_account_role.reader.name
  user_name = snowflake_user.github_ci.name
}

resource "snowflake_grant_account_role" "logger_to_sentinel" {
  provider  = snowflake.useradmin
  role_name = snowflake_account_role.logger.name
  user_name = snowflake_user.sentinel.name
}
