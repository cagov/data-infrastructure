######################################
#      Service Accounts/Users        #
######################################

resource "snowflake_user" "dbt" {
  provider = snowflake.useradmin
  name     = "DBT_SVC_USER_DEV"
  comment  = "Service user for dbt Cloud"

  default_warehouse = module.transforming.name
  default_role      = snowflake_role.transformer.name

  must_change_password = false
  rsa_public_key       = var.dbt_public_key
}


resource "snowflake_user" "airflow" {
  provider = snowflake.useradmin
  name     = "AIRFLOW_SVC_USER_DEV"
  comment  = "Service user for Airflow"

  default_warehouse = module.loading.name
  default_role      = snowflake_role.loader.name

  must_change_password = false
  rsa_public_key       = var.airflow_public_key

}

resource "snowflake_user" "github_ci" {
  provider = snowflake.useradmin
  name     = "GITHUB_CI_SVC_USER_DEV"
  comment  = "Service user for GitHub CI"

  default_warehouse = module.reporting.name
  default_role      = snowflake_role.reader.name

  must_change_password = false
  rsa_public_key       = var.github_ci_public_key
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

resource "snowflake_role_grants" "reader_to_github_ci" {
  provider               = snowflake.useradmin
  role_name              = snowflake_role.reader.name
  enable_multiple_grants = true
  users                  = [snowflake_user.github_ci.name]
}
