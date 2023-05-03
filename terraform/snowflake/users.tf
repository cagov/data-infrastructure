######################################
#      Service Accounts/Users        #
######################################

resource "snowflake_user" "dbt" {
  provider = snowflake.useradmin
  name     = "DBT_SVC_USER_DEV"
  comment  = "Service user for dbt Cloud"

  default_warehouse = snowflake_warehouse.transforming.name
  default_role      = snowflake_role.transformer.name

  must_change_password = false
  rsa_public_key       = var.dbt_public_key
}


resource "snowflake_user" "airflow" {
  provider = snowflake.useradmin
  name     = "AIRFLOW_SVC_USER_DEV"
  comment  = "Service user for Airflow"

  default_warehouse = snowflake_warehouse.loading.name
  default_role      = snowflake_role.loader.name

  must_change_password = false
  rsa_public_key       = var.airflow_public_key

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
