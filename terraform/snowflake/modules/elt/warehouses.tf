#################################
#           Warehouses          #
#################################

# Primary warehouse for loading data to Snowflake from ELT/ETL tools
module "loading" {
  source = "../warehouse"
  providers = {
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }

  name    = "LOADING_${var.environment}"
  comment = "Primary warehouse for loading data to Snowflake from ELT/ETL tools"
}

# Primary warehouse for transforming data. Analytics engineers and automated
# transformation tools should use this warehouse.
module "transforming" {
  source = "../warehouse"
  providers = {
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }

  name    = "TRANSFORMING_${var.environment}"
  comment = "Primary warehouse for transforming data. Analytics engineers and automated transformation tools should use this warehouse"
}

# Primary warehouse for reporting. End-users and BI tools should use this warehouse.
module "reporting" {
  source = "../warehouse"
  providers = {
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }

  name    = "REPORTING_${var.environment}"
  comment = "Primary warehouse for reporting. End-users and BI tools should use this warehouse"
}
