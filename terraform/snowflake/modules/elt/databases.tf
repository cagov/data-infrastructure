#######################################
#            Databases                #
#######################################

# The primary database where transformation tools like dbt operate.
module "transform" {
  source = "../database"
  providers = {
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }
  name                        = "TRANSFORM_${var.environment}"
  comment                     = "Transformation database"
  data_retention_time_in_days = 7
}

# The primary raw database, where ELT tools land data.
module "raw" {
  source = "../database"
  providers = {
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }
  name                        = "RAW_${var.environment}"
  comment                     = "Raw database, intended for ingest of raw data from source systems prior to any modeling or transformation"
  data_retention_time_in_days = 7
}

# The primary reporting database.
module "analytics" {
  source = "../database"
  providers = {
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }
  name                        = "ANALYTICS_${var.environment}"
  comment                     = "Analytics database for data consumers, holding analysis-ready data marts/models"
  data_retention_time_in_days = 7
}
