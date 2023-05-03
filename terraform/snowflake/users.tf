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
  rsa_public_key       = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxGn4yPVeOTBHFDCEf6idprUOLUyR12FICA8UAOtLzYDIqJdSHcQUhrHqqXtPn0Zp8YJbfSbUadNmP5van3F8Q0DcuY+SWOd0MeeSJYkoaib1YTARzLidVn3HSSiQofuSTw60lvc8POMH9Km9q2wLiVmOaGSSbgXBk3K22jb1J2QVoJeOT0awJRgZTAix9TOQEFiUmXZEBe23rPzP86yoERr0JCDlDYjB17S83FxF+gZdpv92Mjbi5s5SBXSPHwIPKUN6qOEAmL5fRheSD+J3TNPmZw8H6w4kYJlSxAQUflumhj7M7eeWwCqnB+OakaBxOVjbe3x80JaVZXPUTnFg0QIDAQAB"
}


resource "snowflake_user" "airflow" {
  provider = snowflake.useradmin
  name     = "AIRFLOW_SVC_USER_DEV"
  comment  = "Service user for Airflow"

  default_warehouse = snowflake_warehouse.loading.name
  default_role      = snowflake_role.loader.name

  must_change_password = false
  rsa_public_key       = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArMGtTtTc+kxRirGFkf6LwlaOxxs1ZyodB0ZhOaNnDexGr5gkmcIv/5fcS5ZYAeLkIwMX+/V8RNBwSLYDfPWzAaZzxldCqQojA4b5RvYhryEor4jlE40WSyWB1gViTs0grqigAcQV5icS53BXIH9dlHR/wtM6U04vKDx9AzhJv2/x35Pc1NLm7RsdaWH9OvKnnySpA1TWoQ3zKFSy8LW79E4MF+mwLy9vwM92GtV4FJqnZeLE75W0QRKfM4kPTLWlDog4MJKw+RQwmNXZj9MrCHV+z9GLkQW3ba0+W8jM0AvPoA8xtJvQ/4g3gCVVfjOt5euQQU8AGkUAt4TTsbm1WwIDAQAB"

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
