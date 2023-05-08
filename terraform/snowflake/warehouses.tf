#################################
#           Warehouses          #
#################################

# Primary warehouse for loading data to Snowflake from ELT/ETL tools
module "loading" {
  source = "./modules/warehouse"
  providers = {
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }

  name    = "LOADING"
  comment = "Primary warehouse for loading data to Snowflake from ELT/ETL tools"
}

# Primary warehouse for transforming data. Analytics engineers and automated
# transformation tools should use this warehouse.
module "transforming" {
  source = "./modules/warehouse"
  providers = {
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }

  name    = "TRANSFORMING"
  comment = "Primary warehouse for transforming data. Analytics engineers and automated transformation tools should use this warehouse"
}

# Primary warehouse for reporting. End-users and BI tools should use this warehouse.
module "reporting" {
  source = "./modules/warehouse"
  providers = {
    snowflake.securityadmin = snowflake.securityadmin,
    snowflake.sysadmin      = snowflake.sysadmin,
    snowflake.useradmin     = snowflake.useradmin,
  }

  name    = "REPORTING"
  comment = "Primary warehouse for reporting. End-users and BI tools should use this warehouse"
}
